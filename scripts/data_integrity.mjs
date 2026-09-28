export function nonEmptyText(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

export function finiteCoordinate(value) {
  if (typeof value === 'number') return Number.isFinite(value) ? value : null;
  if (typeof value !== 'string' || value.trim() === '') return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

export function hasValidKoreanCoordinates(latitude, longitude) {
  const lat = finiteCoordinate(latitude);
  const lng = finiteCoordinate(longitude);
  return lat !== null && lng !== null
    && lat >= 33 && lat <= 39 && lng >= 124 && lng <= 132;
}

export function isValidSnapshotStore(store) {
  return store && typeof store === 'object' && !Array.isArray(store)
    && nonEmptyText(store.storeName)
    && nonEmptyText(store.address)
    && hasValidKoreanCoordinates(store.latitude, store.longitude);
}

export function assertUniqueStoreIds(rows, label) {
  const ids = new Set();
  for (const row of rows) {
    const id = row?.storeId;
    if (!nonEmptyText(id)) throw new Error(`${label} has a missing storeId.`);
    if (ids.has(id)) throw new Error(`${label} has a duplicate storeId: ${id}.`);
    ids.add(id);
  }
}

export function assertSafeSupplementApply({ fetched, previousSupplement, supplement, nextCatalog }) {
  const failed = fetched.filter((row) => row.error);
  if (failed.length > 0) {
    throw new Error(
      `Refusing to apply supplement refresh: ${failed.length} detail request(s) failed. `
      + 'Retry after every candidate detail is available so existing supplement data is retained.',
    );
  }
  assertUniqueStoreIds(previousSupplement, 'Existing supplement');
  assertUniqueStoreIds(supplement, 'Supplement');
  assertUniqueStoreIds(nextCatalog, 'Store-hours catalog');
  const acceptedIds = new Set(supplement.map((store) => store.storeId));
  const missingPreviousIds = previousSupplement
    .map((store) => store?.storeId)
    .filter((id) => nonEmptyText(id) && !acceptedIds.has(id));
  if (missingPreviousIds.length > 0) {
    throw new Error(
      `Refusing to apply supplement refresh: ${missingPreviousIds.length} existing supplement store(s) `
      + 'were not re-accepted. Resolve their source records before replacing the supplement set.',
    );
  }
}
