import { isPossiblePhoneNumber, parsePhoneNumber } from 'react-phone-number-input';

// Legacy application/account snapshots may contain national rather than E.164 values.
// Live input formatting and country selection are handled by react-phone-number-input.
export function normalizeApplicationPhone(value: string) {
  const phone = value.trim().replace(/^00/, '+');
  if (!phone) return '';
  return parsePhoneNumber(phone, { defaultCountry: 'UG', extract: false })?.number || phone;
}

export function validApplicationPhone(value: string) {
  return isPossiblePhoneNumber(normalizeApplicationPhone(value));
}
