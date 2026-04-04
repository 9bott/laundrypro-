/// Loyalty tier from lifetime spend (SAR) — mirrors server rules in Edge Functions.
String getTier(num totalSpent) {
  if (totalSpent >= 2000) return 'gold';
  if (totalSpent >= 500) return 'silver';
  return 'bronze';
}
