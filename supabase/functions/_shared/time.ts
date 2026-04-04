/** Date-only string YYYY-MM-DD in Asia/Riyadh. */
export function riyadhDateString(d = new Date()): string {
  return d.toLocaleDateString("en-CA", { timeZone: "Asia/Riyadh" });
}

/** Start of calendar day in Riyadh as an ISO-anchored Date (UTC instant). */
export function startOfRiyadhDay(d = new Date()): Date {
  const ymd = riyadhDateString(d);
  return new Date(`${ymd}T00:00:00+03:00`);
}

export function endOfRiyadhDay(d = new Date()): Date {
  const s = startOfRiyadhDay(d);
  return new Date(s.getTime() + 24 * 60 * 60 * 1000 - 1);
}

/** Whole days between two instants (floor), using Riyadh calendar boundaries. */
export function wholeDaysBetweenRiyadh(
  earlier: Date,
  later: Date,
): number {
  const a = riyadhDateString(earlier);
  const b = riyadhDateString(later);
  if (a === b) return 0;
  const t0 = startOfRiyadhDay(earlier).getTime();
  const t1 = startOfRiyadhDay(later).getTime();
  return Math.floor((t1 - t0) / (24 * 60 * 60 * 1000));
}
