import {
  forwardRef,
  useEffect,
  useMemo,
  useState,
  type AnchorHTMLAttributes,
  type ReactNode,
} from "react";
import {
  MediaPlayer,
  MediaProvider,
  Track,
  isYouTubeProvider,
  isVimeoProvider,
  type MediaProviderAdapter,
} from "@vidstack/react";
import {
  DefaultVideoLayout,
  defaultLayoutIcons,
} from "@vidstack/react/player/layouts/default";
import "@vidstack/react/player/styles/default/theme.css";
import "@vidstack/react/player/styles/default/layouts/video.css";
import { videoSource, vidstackSource, videoStart } from "@/lib/video-source";
import { Dialog, DialogContent, DialogTitle } from "@/components/ui/dialog";

export function VideoDialogContent({
  title = "Video",
  children,
}: {
  title?: string;
  children: ReactNode;
}) {
  return (
    <DialogContent
      aria-describedby={undefined}
      className='w-[min(96vw,160dvh,1100px)] max-w-none gap-0 overflow-hidden rounded-none border-0 bg-black p-0 sm:rounded-none [&>button]:right-2 [&>button]:top-2 [&>button]:z-10 [&>button]:rounded-full [&>button]:bg-black/70 [&>button]:p-2 [&>button]:text-white [&>button]:opacity-100'
    >
      <DialogTitle className='sr-only'>{title}</DialogTitle>
      {children}
    </DialogContent>
  );
}
export function VideoDialog({
  open,
  onOpenChange,
  title,
  children,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title?: string;
  children: ReactNode;
}) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <VideoDialogContent title={title}>{open && children}</VideoDialogContent>
    </Dialog>
  );
}
function configureProvider(provider: MediaProviderAdapter | null) {
  if (isYouTubeProvider(provider) || isVimeoProvider(provider)) {
    provider.cookies = false;
    provider.iframe.setAttribute(
      "sandbox",
      "allow-scripts allow-same-origin allow-presentation",
    );
    provider.referrerPolicy = "strict-origin-when-cross-origin";
  }
}
export function PlatformVideo({
  src,
  title = "Video",
  force = false,
  captions,
  language = "en",
  start = 0,
  mimeType,
}: {
  src: string;
  title?: string;
  force?: boolean;
  captions?: string;
  language?: string;
  start?: number;
  mimeType?: string;
}) {
  const source = useMemo(
    () => vidstackSource(src, force, mimeType),
    [src, force, mimeType],
  );
  const [failed, setFailed] = useState(false);
  useEffect(() => setFailed(false), [src]);
  if (!source || failed)
    return (
      <div
        role='alert'
        className='grid aspect-[16/9] place-items-center bg-black p-5 text-center text-sm text-white'
      >
        This video cannot be played here. The publisher needs to provide an
        embeddable video or upload the video file.
      </div>
    );
  return (
    <MediaPlayer
      key={source.src}
      title={title}
      src={source}
      viewType='video'
      streamType='on-demand'
      crossOrigin={
        source.type === "video/youtube" ||
        source.type === "video/vimeo" ||
        captions
          ? "anonymous"
          : undefined
      }
      playsInline
      autoPlay
      load='eager' posterLoad='custom'
      currentTime={Math.max(0, start || videoStart(src))}
      onProviderChange={configureProvider}
      onError={() => setFailed(true)}
      className='block aspect-[16/9] w-full overflow-hidden rounded-none border-0 bg-black'
      style={{
        "--media-brand": "#8b5cf6",
        "--media-focus-ring-color": "#a78bfa",
        "--video-border-radius": "0px",
        "--video-border": "none",
        "--video-brand": "#8b5cf6",
      }}
    >
      <MediaProvider>
        {captions && (
          <Track
            src={captions}
            kind='captions'
            language={language}
            label='Captions'
            default
          />
        )}
      </MediaProvider>
      <DefaultVideoLayout
        icons={defaultLayoutIcons}
        noModal
        menuGroup='bottom'
        slots={{ title: null }}
      />
    </MediaPlayer>
  );
}
// Ordinary documents retain their link behavior; video actions stay inside the platform.
export const MediaLink = forwardRef<
  HTMLAnchorElement,
  AnchorHTMLAttributes<HTMLAnchorElement> & { video?: boolean }
>(function MediaLink(
  { href, children, onClick, video = false, ...props },
  ref,
) {
  const [open, setOpen] = useState(false);
  const isVideo = !!href && (video || !!videoSource(href));
  if (!isVideo)
    return (
      <a ref={ref} href={href} onClick={onClick} {...props}>
        {children}
      </a>
    );
  return (
    <>
      <a
        ref={ref}
        {...props}
        href='#video-player'
        target={undefined}
        onClick={(e) => {
          e.preventDefault();
          onClick?.(e);
          setOpen(true);
        }}
      >
        {children}
      </a>
      <VideoDialog open={open} onOpenChange={setOpen}>
        <PlatformVideo src={href!} force={video} />
      </VideoDialog>
    </>
  );
});
