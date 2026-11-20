import { forwardRef, type ButtonHTMLAttributes } from 'react';
import { LoaderCircle } from 'lucide-react';

type Props = ButtonHTMLAttributes<HTMLButtonElement> & { loading?: boolean; loadingText?: string };
export const ButtonLoader = forwardRef<HTMLButtonElement, Props>(function ButtonLoader({ loading = false, loadingText = 'Saving...', disabled, children, type = 'button', ...props }, ref) {
  return <button ref={ref} type={type} {...props} disabled={disabled || loading} aria-busy={loading}>{loading ? <><LoaderCircle aria-hidden="true" size={18} className="shrink-0 motion-safe:animate-spin"/>{loadingText}</> : children}</button>;
});
