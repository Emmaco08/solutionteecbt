import React from "react";
import { Composition } from "remotion";
import { Intro } from "./Intro";
import { Short } from "./short/Short";
import { AdTomorrow, TOMORROW_SECONDS } from "./pack/AdTomorrow";
import { AdStop, STOP_SECONDS } from "./pack/AdStop";
import { AdScreen, SCREEN_SECONDS } from "./pack/AdScreen";
import { AdStruggle, STRUGGLE_SECONDS } from "./major/AdStruggle";
import { AdOneApp, ONEAPP_SECONDS } from "./major/AdOneApp";
import { FeatAI, AI_SECONDS } from "./feat/FeatAI";
import { FeatMock, MOCK_SECONDS } from "./feat/FeatMock";
import { FeatGame, GAME_SECONDS } from "./feat/FeatGame";
import { FeatLive, LIVE_SECONDS } from "./feat/FeatLive";
import { FeatOffline, OFFLINE_SECONDS } from "./feat/FeatOffline";
import { FeatBoard, BOARD_SECONDS } from "./feat/FeatBoard";
import { WinAd, WIN_SECONDS } from "./win/WinAd";

// Social ads pack (D-182): every ad in 9:16 (TikTok, Reels, Stories, WhatsApp Status) and 4:5 (Facebook and Instagram feeds).
const both = (id: string, C: React.FC, seconds: number) => (
  <>
    <Composition id={`${id}916`} component={C} durationInFrames={Math.round(seconds * 30)} fps={30} width={1080} height={1920} />
    <Composition id={`${id}45`} component={C} durationInFrames={Math.round(seconds * 30)} fps={30} width={1080} height={1350} />
  </>
);

export const Root: React.FC = () => (
  <>
    <Composition id="Intro916" component={Intro} durationInFrames={1800} fps={30} width={1080} height={1920} />
    <Composition id="Short916" component={Short} durationInFrames={900} fps={30} width={1080} height={1920} />
    {both("AdTomorrow", AdTomorrow, TOMORROW_SECONDS)}
    {both("AdStop", AdStop, STOP_SECONDS)}
    {both("AdScreen", AdScreen, SCREEN_SECONDS)}
    {/* Two major adverts (D-183): 9:16 first; 4:5 and 16:9 cuts after the owner approves the vertical one. */}
    {both("AdStruggle", AdStruggle, STRUGGLE_SECONDS)}
    {both("AdOneApp", AdOneApp, ONEAPP_SECONDS)}
    {/* Feature ads (D-184): one ad, one major feature */}
    {both("FeatAI", FeatAI, AI_SECONDS)}
    {both("FeatMock", FeatMock, MOCK_SECONDS)}
    {both("FeatGame", FeatGame, GAME_SECONDS)}
    {both("FeatLive", FeatLive, LIVE_SECONDS)}
    {both("FeatOffline", FeatOffline, OFFLINE_SECONDS)}
    {both("FeatBoard", FeatBoard, BOARD_SECONDS)}
    {/* "Now on Windows" (D-186): also 16:9 for YouTube, X and the website */}
    {both("WinAd", WinAd, WIN_SECONDS)}
    <Composition id="WinAd169" component={WinAd} durationInFrames={WIN_SECONDS * 30} fps={30} width={1920} height={1080} />
  </>
);
