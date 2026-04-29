#pragma once

#include "ap_axi_sdata.h"
#include "hls_stream.h"
#include "ap_int.h"
#include <iostream>
#include <fstream>

// Same AXI-Stream packet type as part1: 32-bit data, user/id/dest side-channels
typedef ap_axis<32, 2, 5, 6> packet;

#define NUM_TAPS    15   // FIR filter order (15-tap low-pass)
#define NUM_SAMPLES 32   // number of test samples (matches fir_golden)

void fir(hls::stream<packet>& in_s, hls::stream<packet>& out_s);
