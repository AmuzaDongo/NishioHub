import { useState, type InputHTMLAttributes } from 'react';
import PhoneNumberInput, { getCountryCallingCode, type Country, type FlagProps, type Props } from 'react-phone-number-input';
import 'react-phone-number-input/style.css';
import { cn } from '@/lib/utils';

type PhoneInputProps = Omit<Props<InputHTMLAttributes<HTMLInputElement>>, 'value' | 'onChange'> & {
  value: string;
  onChange: (value: string) => void;
};

// Local emoji flags keep the country selector independent of an external CDN.
function CountryFlag({ country, countryName }: FlagProps) {
  const flag = String.fromCodePoint(...Array.from(country).map(letter => letter.charCodeAt(0) + 127397));
  return <span className="flex items-center gap-1 whitespace-nowrap text-xs font-normal" title={countryName}>
    <span aria-hidden="true">{flag}</span><span>+{getCountryCallingCode(country)}</span>
  </span>;
}

export function PhoneInput({ value, onChange, className, countrySelectProps, defaultCountry = 'UG', onCountryChange, ...props }: PhoneInputProps) {
  const [country, setCountry] = useState<Country | undefined>(defaultCountry);
  return <PhoneNumberInput
    {...props}
    defaultCountry={country}
    onCountryChange={next => { setCountry(next); onCountryChange?.(next); }}
    value={value || undefined}
    onChange={next => onChange(next || '')}
    flagComponent={CountryFlag}
    countrySelectProps={{ 'aria-label': 'Phone country code', ...countrySelectProps }}
    className={cn(
      '[--PhoneInput-color--focus:#7c3aed] flex h-9 w-full rounded-lg border border-[#c7c1df] bg-white text-sm font-normal focus-within:border-violet-600 focus-within:ring-2 focus-within:ring-violet-100',
      '[&_.PhoneInputCountry]:mr-0 [&_.PhoneInputCountry]:border-r [&_.PhoneInputCountry]:border-[#c7c1df] [&_.PhoneInputCountry]:px-2',
      '[&_.PhoneInputCountryIcon--border]:!h-auto [&_.PhoneInputCountryIcon--border]:!w-auto [&_.PhoneInputCountryIcon--border]:!bg-transparent [&_.PhoneInputCountryIcon--border]:!shadow-none',
      '[&_.PhoneInputInput]:h-full [&_.PhoneInputInput]:min-w-0 [&_.PhoneInputInput]:rounded-r-lg [&_.PhoneInputInput]:bg-transparent [&_.PhoneInputInput]:px-2 [&_.PhoneInputInput]:outline-none [&_.PhoneInputInput]:disabled:text-slate-600',
      className,
    )}
  />;
}
