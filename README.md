# FPGA Audio Synthesizer

An FPGA-based audio synthesizer developed as part of the **Logic Synthesis** course at Tampere University.

The project focuses on RTL design, waveform generation, audio control, I²C communication, and hardware verification using VHDL.

## Project Overview

The design brings together several digital hardware modules to implement an audio synthesis system. It includes waveform generation logic, arithmetic modules, an audio control interface, and an I²C configuration controller for the DA7212 audio codec.

The implementation follows a modular RTL architecture, with dedicated VHDL testbenches for functional verification.

## Key Components

| Module | Description |
|---|---|
| `synthesizer.vhd` | Main audio synthesizer module |
| `wave_gen.vhd` | Digital waveform generator |
| `audio_ctrl.vhd` | Audio control logic |
| `i2c_config.vhd` | I²C controller for audio codec configuration |
| `adder.vhd` | Arithmetic addition module |
| `multi_port_adder.vhd` | Multi-input arithmetic module |
| `audio_codec_model.vhd` | Audio codec model used in the design environment |

## Repository Structure

```text
Audio-Synthesizer/
├── rtl/                # VHDL design modules
├── tb/                 # VHDL testbenches and support packages
├── constraints/        # FPGA constraints
├── syn/                # Synthesis-related files
└── README.md
```

## Verification

The repository contains dedicated VHDL testbenches for verifying the main hardware components, including:

- Waveform generator
- Audio control logic
- I²C configuration controller
- Arithmetic modules
- Integrated synthesizer

Simulation is used to examine functional behavior, FSM transitions, and signal timing.

## Tools and Technologies

- **Language:** VHDL
- **FPGA Development:** AMD Xilinx Vivado
- **Simulation:** ModelSim
- **Design Concepts:** RTL, finite state machines, synchronous digital logic, digital audio, I²C
