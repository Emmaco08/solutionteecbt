import { Config } from "@remotion/cli/config";

// Use the browser already on this machine (no download). Change or remove on another computer.
Config.setBrowserExecutable(process.env.REMOTION_CHROME ?? "/opt/pw-browsers/chromium_headless_shell-1243/chrome-headless-shell-linux64/chrome-headless-shell");
Config.setVideoImageFormat("jpeg");
Config.setJpegQuality(95);
Config.setConcurrency(4);
Config.setChromiumOpenGlRenderer("angle");
