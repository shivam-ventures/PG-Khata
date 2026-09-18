"use client";

import * as React from "react";

/** Used to switch between the mobile bottom-tab-bar and the desktop sidebar. */
export function useMediaQuery(query: string) {
  const [matches, setMatches] = React.useState(false);

  React.useEffect(() => {
    const mql = window.matchMedia(query);
    const onChange = () => setMatches(mql.matches);
    onChange();
    mql.addEventListener("change", onChange);
    return () => mql.removeEventListener("change", onChange);
  }, [query]);

  return matches;
}

/** Desktop breakpoint used for the sidebar/bottom-tab-bar switch across the whole app. */
export function useIsDesktop() {
  return useMediaQuery("(min-width: 1024px)");
}
