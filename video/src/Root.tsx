import React from "react";
import { Composition } from "remotion";
import { Intro } from "./Intro";

export const Root: React.FC = () => (
  <>
    <Composition id="Intro916" component={Intro} durationInFrames={1800} fps={30} width={1080} height={1920} />
  </>
);
