import { useCallback, useEffect, useLayoutEffect, useRef } from 'react';

import { FormattedMessage } from 'react-intl';

import classNames from 'classnames';

interface Props {
  hidden?: boolean;
  sensitive: boolean;
  uncached?: boolean;
  matchedFilters?: string[];
  onClick: React.MouseEventHandler<HTMLButtonElement>;
  // Called when the button is long-pressed / released afterwards.
  onPeekStart?: () => void;
  onPeekEnd?: () => void;
}

export const SpoilerButton: React.FC<Props> = ({
  hidden = false,
  sensitive,
  uncached = false,
  matchedFilters,
  onClick,
  onPeekStart,
  onPeekEnd,
}) => {
  const { handleClick, handlePointerDown, handleContextMenu } =
    useLongPressPeek({ onClick, onPeekStart, onPeekEnd });

  let warning;
  let action;

  if (uncached) {
    warning = (
      <FormattedMessage
        id='status.uncached_media_warning'
        defaultMessage='Preview not available'
      />
    );
    action = (
      <FormattedMessage id='status.media.open' defaultMessage='Click to open' />
    );
  } else if (matchedFilters?.length) {
    warning = (
      <FormattedMessage
        id='filter_warning.matches_filter'
        defaultMessage='Matches filter “<span>{title}</span>”'
        values={{
          title: matchedFilters.join(', '),
          span: (chunks) => <span className='filter-name'>{chunks}</span>,
        }}
      />
    );
    action = (
      <FormattedMessage id='status.media.show' defaultMessage='Click to show' />
    );
  } else if (sensitive) {
    warning = (
      <FormattedMessage
        id='status.sensitive_warning'
        defaultMessage='Sensitive content'
      />
    );
    action = (
      <FormattedMessage id='status.media.show' defaultMessage='Click to show' />
    );
  } else {
    warning = (
      <FormattedMessage
        id='status.media_hidden'
        defaultMessage='Media hidden'
      />
    );
    action = (
      <FormattedMessage id='status.media.show' defaultMessage='Click to show' />
    );
  }

  return (
    <div
      className={classNames('spoiler-button', {
        'spoiler-button--hidden': hidden,
        'spoiler-button--click-thru': uncached,
      })}
    >
      <button
        type='button'
        className='spoiler-button__overlay'
        onClick={handleClick}
        onPointerDown={handlePointerDown}
        onContextMenu={handleContextMenu}
        disabled={uncached}
      >
        <span className='spoiler-button__overlay__label'>
          <span className='spoiler-button__overlay__text'>{warning}</span>
          <span className='spoiler-button__overlay__action'>{action}</span>
        </span>
      </button>
    </div>
  );
};

const LONG_PRESS_DELAY_MS = 500;

// setTimeout that is cancelled when the signal is aborted.
const abortableTimeout = (
  callback: () => void,
  delay: number,
  signal: AbortSignal,
) => {
  if (signal.aborted) {
    return;
  }

  const timer = setTimeout(() => {
    signal.removeEventListener('abort', onAbort);
    callback();
  }, delay);

  const onAbort = () => {
    clearTimeout(timer);
  };
  signal.addEventListener('abort', onAbort, { once: true });
};

// Detects a long press and reports it via onPeekStart / onPeekEnd (on release).
// The click that follows a long press is swallowed.
function useLongPressPeek({
  onClick,
  onPeekStart,
  onPeekEnd,
}: Pick<Props, 'onClick' | 'onPeekStart' | 'onPeekEnd'>) {
  const pressAbort = useRef<AbortController | null>(null);
  const peeked = useRef(false);
  const suppressClick = useRef(false);
  const onPeekEndRef = useRef(onPeekEnd);
  useLayoutEffect(() => {
    onPeekEndRef.current = onPeekEnd;
  }, [onPeekEnd]);

  const endPress = useCallback(() => {
    pressAbort.current?.abort();
    pressAbort.current = null;

    if (peeked.current) {
      peeked.current = false;
      suppressClick.current = true;
      onPeekEndRef.current?.();
      // Clear the flag in case no click event follows the release.
      setTimeout(() => {
        suppressClick.current = false;
      }, 0);
    }
  }, []);

  useEffect(() => endPress, [endPress]);

  const handlePointerDown = useCallback(
    (e: React.PointerEvent) => {
      if (!onPeekStart || (e.pointerType === 'mouse' && e.button !== 0)) {
        return;
      }

      endPress();

      const controller = new AbortController();
      const { signal } = controller;
      pressAbort.current = controller;
      document.addEventListener('pointerup', endPress, { signal });
      document.addEventListener('pointercancel', endPress, { signal });

      abortableTimeout(
        () => {
          peeked.current = true;
          onPeekStart();
        },
        LONG_PRESS_DELAY_MS,
        signal,
      );
    },
    [endPress, onPeekStart],
  );

  const handleClick = useCallback<React.MouseEventHandler<HTMLButtonElement>>(
    (e) => {
      if (suppressClick.current) {
        suppressClick.current = false;
        return;
      }
      onClick(e);
    },
    [onClick],
  );

  const handleContextMenu = useCallback((e: React.MouseEvent) => {
    if (peeked.current) {
      e.preventDefault();
    }
  }, []);

  return { handleClick, handlePointerDown, handleContextMenu };
}
