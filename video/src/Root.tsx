import React from "react";
import { Composition } from "remotion";
import { Intro } from "./Intro";
import { Short } from "./short/Short";
import { AdTomorrow, TOMORROW_SECONDS } from "./pack/AdTomorrow";
import { AdStop, STOP_SECONDS } from "./pack/AdStop";
import { AdScreen, SCREEN_SECONDS } from "./pack/AdScreen";

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
  </>
);
