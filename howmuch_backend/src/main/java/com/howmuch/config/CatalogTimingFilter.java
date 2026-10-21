package com.howmuch.config;

import com.howmuch.diagnostics.CatalogTiming;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletOutputStream;
import jakarta.servlet.WriteListener;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpServletResponseWrapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.io.FilterWriter;
import java.io.PrintWriter;
import java.io.Writer;

/** Streams unchanged JSON; measures application work, never client download time. */
@Slf4j
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 1)
public class CatalogTimingFilter extends OncePerRequestFilter {
    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getServletPath();
        if (path.isEmpty()) path = request.getRequestURI();
        return !"GET".equals(request.getMethod())
                || !("/api/stores/catalog".equals(path) || "/api/stores/all".equals(path));
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {
        CatalogTiming timing = CatalogTiming.begin();
        TimedResponse wrapped = new TimedResponse(response, timing);
        boolean failed = false;
        try {
            chain.doFilter(request, wrapped);
        } catch (IOException | ServletException | RuntimeException | Error exception) {
            failed = true;
            throw exception;
        } finally {
            try {
                wrapped.beforeWrite(); // Empty/304 responses do not write a body.
                long dispatchNanos = timing.elapsedNanos();
                log.info("[CatalogTiming] request_id={} route={} status={} failed={} {} phases=[{}] app_dispatch_ms={} app_after_prewrite_ms={} output_bytes={}",
                        timing.requestId(), request.getServletPath().endsWith("/all")
                                || request.getRequestURI().equals("/api/stores/all") ? "all" : "catalog",
                        response.getStatus(), failed, timing.summary(),
                        timing.serverTiming(wrapped.prewriteNanos), CatalogTiming.millis(dispatchNanos),
                        CatalogTiming.millis(Math.max(0, dispatchNanos - wrapped.prewriteNanos)), failed ? -1 : wrapped.bytes);
            } finally {
                CatalogTiming.clear();
            }
        }
    }

    private static final class TimedResponse extends HttpServletResponseWrapper {
        private final CatalogTiming timing;
        private ServletOutputStream stream;
        private PrintWriter writer;
        private boolean outputStreamSelected;
        private long prewriteNanos = -1;
        private long bytes;

        TimedResponse(HttpServletResponse response, CatalogTiming timing) {
            super(response);
            this.timing = timing;
        }

        void beforeWrite() {
            if (prewriteNanos >= 0) return;
            prewriteNanos = timing.elapsedNanos();
            if (!isCommitted()) {
                setHeader("Server-Timing", timing.serverTiming(prewriteNanos));
                setHeader("X-Catalog-Request-Id", timing.requestId());
            }
        }

        private ServletOutputStream timedStream() throws IOException {
            if (stream == null) {
                ServletOutputStream delegate = super.getOutputStream();
                stream = new ServletOutputStream() {
                    @Override public boolean isReady() { return delegate.isReady(); }
                    @Override public void setWriteListener(WriteListener listener) { delegate.setWriteListener(listener); }
                    @Override public void write(int value) throws IOException {
                        beforeWrite();
                        delegate.write(value);
                        bytes++;
                    }
                    @Override public void write(byte[] value, int offset, int length) throws IOException {
                        if (length > 0) beforeWrite();
                        delegate.write(value, offset, length);
                        bytes += length;
                    }
                    @Override public void flush() throws IOException { beforeWrite(); delegate.flush(); }
                    @Override public void close() throws IOException { beforeWrite(); delegate.close(); }
                };
            }
            return stream;
        }

        @Override public ServletOutputStream getOutputStream() throws IOException {
            if (writer != null) throw new IllegalStateException("Writer already selected");
            outputStreamSelected = true;
            return timedStream();
        }

        @Override public PrintWriter getWriter() throws IOException {
            if (outputStreamSelected) throw new IllegalStateException("Output stream already selected");
            if (writer == null) {
                // Delegate encoding/buffering to the container; never own an unflushed body buffer.
                bytes = -1; // Character writes are not an encoded-byte measurement.
                Writer delegate = super.getWriter();
                writer = new PrintWriter(new FilterWriter(delegate) {
                    @Override public void write(int value) throws IOException { beforeWrite(); out.write(value); }
                    @Override public void write(char[] value, int offset, int length) throws IOException {
                        if (length > 0) beforeWrite();
                        out.write(value, offset, length);
                    }
                    @Override public void write(String value, int offset, int length) throws IOException {
                        if (length > 0) beforeWrite();
                        out.write(value, offset, length);
                    }
                    @Override public void flush() throws IOException { beforeWrite(); out.flush(); }
                    @Override public void close() throws IOException { beforeWrite(); out.close(); }
                });
            }
            return writer;
        }

        @Override public void flushBuffer() throws IOException {
            beforeWrite();
            if (writer != null) writer.flush();
            super.flushBuffer();
        }

        @Override public void sendError(int status) throws IOException { beforeWrite(); super.sendError(status); }
        @Override public void sendError(int status, String message) throws IOException { beforeWrite(); super.sendError(status, message); }
        @Override public void sendRedirect(String location) throws IOException { beforeWrite(); super.sendRedirect(location); }
    }
}
