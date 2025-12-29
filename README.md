# Calculator Architecture Project: RISC Pipeline and Branch Target Buffer (BTB)

## Project Description

This project is part of the **Calculator Architecture 1 & 2** modules. Its goal is to analyze, modify, and optimize an initially **5-stage pipeline** RISC processor (CS3) and integrating a **Branch Target Buffer (CS4)** to reduce penalties caused by branch instructions.

The project is fully implemented in **VHDL**, major modifications are in `datapath.vhd` and `CU.vhd`

---

## Project Structure
- **CS3: 5-Stage Pipeline**  
  - The given pipeline is  5-staged: Fetch, Decode, Execute, Memory, Write Back with Control Unit and Hazard management to be implemented.
  - Commands generated using combinational logic, see in `CU.vhd`
  - Hazard management: bubbles and RAW hazards, see in `datapath.vhd` 

- **CS4: Branch Target Buffer (BTB)**  
  - Objectif: Predicts jumps and unconditional branches to avoid pipeline bubbles  
  - The given code has a configurable BTB size (1–8 lines)  and two replacement policies to be implemented: FIFO and LRU (shift-register counters used for LRU)  
  - Synchronized with pipeline and reset process to prevent update errors  

---

## Tools and Environment

- **Language**: VHDL  
- **IDE / Synthesis**: Intel Quartus Prime  
- **Simulation / Waveforms**: `.do` files provided for monitoring key signals (PC, bubble, RAW, BTB_match, BTB_x, cmds_x)  
---

## Features

- Fully functional 5-stage pipeline with command aging for proper stage synchronization  
- Hazard management for bubbles and RAW conflicts  
- Implementation of **BTB** for jumps and unconditional branches  
- FIFO and LRU strategies for BTB replacement  
- Simulations verify:
  - Correct detection of pipeline bubbles  
  - Accurate program counter (PC) calculation  
  - Detection of BTB misses (BTB_J, BTB_B, BTB_IB)  
  - Proper pipeline progression  
  - Correct register file updates  

---

## Lessons Learned

- Understanding and comparing non-pipelined vs pipelined RISC architectures  
- Implementing and debugging a pipeline with hazard handling  
- Designing a hardware-efficient Branch Target Buffer (FIFO & LRU)  
- Leveraging VHDL to model, simulate, and optimize a processor at the RTL level  
- Using Quartus Prime for synthesis, RTL analysis, and timing evaluation  

---

## Results

| Configuration | Logic Elements | Memory Bits | Registers | Fmax (MHz) | Execution Time (ns) |
|---------------|----------------|------------|-----------|------------|-------------------|
| CS3 (Non-optimized version)          | 400            | 1536       | 194       | 111.77     | 3912.5            |
| CS4 *Optimized version)         | 575            | 1536       | 258       | 92.03      | 3412              |

- Pipelined versions (CS3/CS4) reduce logic elements and registers while increasing throughput  
- BTB in CS4 improves pipeline efficiency by reducing control hazards  
- Maximum operating frequency significantly improved in pipelined architectures  

---

## Usage

1. Download the project archive `Arc4-25_BTB_in_pipeline.qar` and open in Quartus Prime via "Open Project".  
2. Synthesize the design and run RTL simulation using the provided `.do` scripts.  
3. Observe signals such as `PC`, `bubble`, `RAW`, and `BTB_x` in the waveform viewer.  

---

## Acknowledgments
Project completed as part of the **Calculator Architecture 2** course, leveraging knowledge from **VHDL programming** and processor pipeline design.
