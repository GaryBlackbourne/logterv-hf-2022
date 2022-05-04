# Flanger design for Xilinx FPGA

This project is a homework for logical design class at BME. 

## How to build
The project only contains source files only, not the entire project. To build, (synthesize) create a new project in Vivado and import the source files from `src_verilog`. The flanger signal generation script can be found in `signal_generation` directory. 

## Overview
The project contains verilog modules for a Xilinx Kintex-7 FPGA. The modules implement a flanger for stereo audio signals and a CODEC interface module. The design was created with the [Logsys](http://logsys.mit.bme.hu/) development system.

## etc
Target: `Xilinx XC7K70T-1FBG676I`

Dev Env: `Xilinx Vivado`
