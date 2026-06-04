enum GuardianState {
  unauthenticated,
  unverified, // KYC required
  noChild,
  unpairedChild,
  collectingData,
  dataReady,
  authenticated,
}
