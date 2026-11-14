import React from "react";
import { Composition } from "remotion";
import { Intro } from "./Intro";
import { Short } from "./short/Short";

export const Root: React.FC = () => (
  <>
    <Composition id="Intro916" component={Intro} durationInFrames={1800} fps={30} width={1080} height={1920} />
    <Composition id="Short916" component={Short} durationInFrames={900} fps={30} width={1080} height={1920} />
  </>
);
