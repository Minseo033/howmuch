import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:howmuch/features/store/store_model.dart';

class FilteredResultsScreen extends StatefulWidget {
  const FilteredResultsScreen({super.key});

  @override
  State<FilteredResultsScreen> createState() => _FilteredResultsScreenState();
}

class _FilteredResultsScreenState extends State<FilteredResultsScreen> {
  late Future<List<Store>> _storesFuture;

  @override
  void initState() {
    super.initState();
    _storesFuture = _fetchStores();
  }

  Future<List<Store>> _fetchStores() async {
    try {
      // 백엔드 API 호출
      final response = await http.get(Uri.parse('http://localhost:8081/api/test/stores'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((json) => Store.fromJson(json)).toList();
      } else {
        throw Exception('데이터 로드 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('서버 연결 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('착한가격업소 목록'),
        backgroundColor: Colors.orangeAccent,
      ),
      body: FutureBuilder<List<Store>>(
        future: _storesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('에러 발생: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('검색 결과가 없습니다.'));
          }

          final stores = snapshot.data!;
          return ListView.builder(
            itemCount: stores.length,
            itemBuilder: (context, index) {
              final store = stores[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    store.storeName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text('📍 ${store.address}'),
                      const SizedBox(height: 4),
                      Text('📞 ${store.phoneNumber}'),
                      const SizedBox(height: 4),
                      if (store.menu1.isNotEmpty)
                        Text(
                          '🍴 대표메뉴: ${store.menu1} (${store.price1}원)',
                          style: const TextStyle(color: Colors.deepOrange),
                        ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // 추후 상세 페이지 이동 로직 추가 가능
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
