import React from "react";
import { AbsoluteFill, Audio, staticFile } from "remotion";
import { Finish, Scene } from "./components";
import { Ai, Cbt, Cold, Logos, Meet, Ready, Result } from "./scenes1";
import { Cash, Classes, Games, Leader, Offline, Outro, Wall } from "./scenes2";

/** SolutionTee CBT intro advert (D-164). Times are seconds; see src/timeline.json and docs/plans/advert-intro.md. */
export const Intro: React.FC = () => (
  <AbsoluteFill style={{ background: "#02060F" }}>
    <Scene from={0} to={2.1}><Cold /></Scene>
    <Scene from={2.0} to={4.8}><Logos /></Scene>
    <Scene from={4.3} to={5.8}><Ready /></Scene>
    <Scene from={6.0} to={8.4}><Meet /></Scene>
    <Scene from={7.3} to={12.2}><Cbt /></Scene>
    <Scene from={11.85} to={16.2}><Result /></Scene>
    <Scene from={15.85} to={20.2}><Ai /></Scene>
    <Scene from={19.95} to={24.1}><Offline /></Scene>
    <Scene from={24.0} to={28.1}><Games /></Scene>
    <Scene from={27.9} to={34.1}><Cash /></Scene>
    <Scene from={33.9} to={38.1}><Leader /></Scene>
    <Scene from={37.9} to={44.1}><Classes /></Scene>
    <Scene from={43.95} to={47.8}><Wall /></Scene>
    <Scene from={47.98} to={60}><Outro /></Scene>
    <Scene from={0} to={60}><Finish /></Scene>
    <Audio src={staticFile("audio/mix.wav")} />
  </AbsoluteFill>
);
