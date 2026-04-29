#!/usr/bin/env python3
"""
FPGA-Friendly FIR Filter Generator
- 64-tap FIR filter with Q15 format coefficients
- Power-of-2 scaling (no division needed!)
- Generates plots and SystemVerilog readmem files

Author: Generated for FPGA implementation
"""

import numpy as np
import matplotlib.pyplot as plt
import os

# ============================================================================
# Configuration
# ============================================================================
SAMPLE_RATE = 48000  # Hz
DURATION = 5.0       # seconds
N_SAMPLES = int(SAMPLE_RATE * DURATION)
N_TAP = 64           # FIR filter taps
CUTOFF_FREQ = 5000   # Hz (low-pass cutoff)
CUTOFF_HP = 8000     # Hz (high-pass cutoff)
Q15_SCALE = 32768    # 2^15 for Q0.15 format

# Simulation samples for fast verification (Verilog simulation)
N_SIM_SAMPLES = 1000  # Input samples for Verilog simulation
N_SIM_OUTPUT = N_SIM_SAMPLES - N_TAP + 1  # Expected output samples: 937

# Output directories
OUTPUT_DIR = "numpy_outputs"
PLOT_DIR = "plots"
READMEM_DIR = "verilog_files"

# ============================================================================
# FIR Filter Coefficient Generation
# ============================================================================
def generate_fir_coefficients(n_tap, cutoff_norm, filter_type='lowpass'):
    """
    Generate FIR filter coefficients using windowed sinc method.
    
    Args:
        n_tap: Number of taps (64 for this design)
        cutoff_norm: Normalized cutoff frequency (0.0 to 1.0)
        filter_type: 'lowpass' or 'highpass'
    
    Returns:
        coeffs: FIR coefficients (float)
    """
    n = np.arange(n_tap)
    
    # For symmetric FIR, use fractional center
    center = (n_tap - 1) / 2.0  # e.g., 31.5 for 64 taps
    
    # Generate sinc function using sin(x)/x with proper centering
    with np.errstate(divide='ignore', invalid='ignore'):
        x = 2 * cutoff_norm * (n - center)
        coeffs = np.sin(np.pi * x) / (np.pi * x)
    
    # Handle the center sample where x=0 (sinc(0)=1)
    coeffs[np.isnan(coeffs)] = 1.0
    
    if filter_type == 'highpass':
        # High-pass: negate and add impulse at center
        coeffs = -coeffs
        coeffs[int(center)] = 1.0 - coeffs[int(center)]
    
    # Apply Hamming window
    window = 0.54 - 0.46 * np.cos(2 * np.pi * n / (n_tap - 1))
    coeffs *= window
    
    # Normalize to unity gain
    if filter_type == 'lowpass':
        coeffs /= np.sum(coeffs)
    else:
        coeffs /= np.sum(np.abs(coeffs))
    
    return coeffs

def quantize_to_q15(coeffs_float):
    """
    Quantize float coefficients to Q0.15 format (int16).
    
    Q0.15: 1 sign bit + 15 fractional bits
    Range: -1.0 to 0.99997
    
    Args:
        coeffs_float: Float coefficients
    
    Returns:
        coeffs_q15: Quantized int16 coefficients
    """
    # Scale by 2^15 and round
    coeffs_q15 = np.round(coeffs_float * Q15_SCALE).astype(np.int16)
    
    # Clamp to int16 range
    coeffs_q15 = np.clip(coeffs_q15, -32768, 32767)
    
    return coeffs_q15

# ============================================================================
# FIR Filter Implementation (No convolution!)
# ============================================================================
def fir_filter_manual(signal, coeffs, mode='same'):
    """
    Implement FIR filter using manual loop multiplication.
    No numpy conv or similar functions used!
    
    Args:
        signal: Input signal (int16 array)
        coeffs: FIR coefficients (int16 array)
        mode: 'same' - output same length as input (assumes zeros before first sample)
              'valid' - output only where all taps overlap (N - M + 1 samples)
    
    Returns:
        output: Filtered output (int16 array)
    """
    n_signal = len(signal)
    n_tap = len(coeffs)
    
    if mode == 'valid':
        output_len = n_signal - n_tap + 1
    else:  # 'same'
        output_len = n_signal
    
    output = np.zeros(output_len, dtype=np.int16)
    
    # Manual FIR using nested loops
    for i in range(output_len):
        acc = np.int64(0)  # Use 64-bit accumulator to avoid overflow
        
        # Convolution: sum of products
        for j in range(n_tap):
            sample_idx = i + j  # For 'valid' mode, this aligns correctly
            if mode == 'same':
                sample_idx = i + j  # Shift for same mode
                if sample_idx < n_signal:
                    sample = np.int64(signal[sample_idx])
                else:
                    sample = np.int64(0)  # Zero pad
            else:  # 'valid'
                sample = np.int64(signal[sample_idx])
            
            coeff = np.int64(coeffs[j])
            # 16-bit × 16-bit multiplication → 32-bit result
            acc += sample * coeff
        
        # Q15 scaling: right shift by 15 (divide by 32768)
        # Using >> for signed arithmetic in Python
        output[i] = np.int16(acc >> 15)
    
    return output

def fir_filter_float(signal_float, coeffs_float, mode='valid'):
    """
    Reference FIR filter using float arithmetic.
    
    Args:
        signal_float: Input signal (float)
        coeffs_float: FIR coefficients (float)
        mode: 'valid' or 'same'
    
    Returns:
        output: Filtered output (float)
    """
    n_signal = len(signal_float)
    n_tap = len(coeffs_float)
    
    if mode == 'valid':
        output_len = n_signal - n_tap + 1
    else:
        output_len = n_signal
    
    output = np.zeros(output_len, dtype=np.float64)
    
    for i in range(output_len):
        acc = 0
        for j in range(n_tap):
            sample_idx = i + j
            if mode == 'same' and sample_idx >= n_signal:
                sample = 0
            else:
                sample = signal_float[sample_idx]
            acc += sample * coeffs_float[j]
        output[i] = acc
    
    return output

# ============================================================================
# Signal Generation
# ============================================================================
def generate_test_signal(n_samples, sample_rate):
    """
    Generate a test signal with multiple frequency components.
    
    Contains:
    - Low frequency (500 Hz)
    - Mid frequency (5 kHz) - at cutoff
    - High frequency (15 kHz)
    - White noise
    
    Args:
        n_samples: Number of samples
        sample_rate: Sample rate in Hz
    
    Returns:
        signal: Generated signal (float)
    """
    t = np.arange(n_samples) / sample_rate
    
    # Multi-frequency test signal
    signal = (
        0.5 * np.sin(2 * np.pi * 500 * t) +      # 500 Hz (low)
        0.3 * np.sin(2 * np.pi * 5000 * t) +     # 5 kHz (at cutoff)
        0.3 * np.sin(2 * np.pi * 15000 * t) +    # 15 kHz (high)
        0.1 * np.random.randn(n_samples)          # White noise
    )
    
    # Normalize to ±1 range
    signal = signal / np.max(np.abs(signal))
    
    return signal

def float_to_int16(signal_float):
    """
    Convert float signal to int16.
    
    Args:
        signal_float: Float signal (±1 range)
    
    Returns:
        signal_int16: Int16 signal
    """
    return np.round(signal_float * 32767).astype(np.int16)

def int16_to_float(signal_int16):
    """
    Convert int16 signal to float.
    
    Args:
        signal_int16: Int16 signal
    
    Returns:
        signal_float: Float signal (±1 range)
    """
    return signal_int16.astype(np.float64) / 32767.0

# ============================================================================
# SystemVerilog Readmem File Generation
# ============================================================================
def write_readmem_file(filename, data, data_width=16):
    """
    Write data to SystemVerilog readmem format.
    
    Format: @ADDRESS DATA (hex)
    
    Args:
        filename: Output filename
        data: Data array
        data_width: Bit width of each sample
    """
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    
    with open(filename, 'w') as f:
        f.write("// SystemVerilog readmem file\n")
        f.write(f"// Data width: {data_width} bits\n")
        f.write(f"// Samples: {len(data)}\n")
        f.write("\n")
        
        for i, val in enumerate(data):
            # Convert to int64 first, then mask to avoid overflow
            unsigned_val = int(np.int64(val) & ((1 << data_width) - 1))
            # Format as hex: @ADDR DATA
            f.write(f"@{i:08x} {unsigned_val:04x}\n")
    
    print(f"  Wrote {len(data)} samples to {filename}")

# ============================================================================
# Visualization
# ============================================================================
def plot_coefficients(lp_coeffs, hp_coeffs, save_path):
    """
    Plot FIR filter coefficients in time and frequency domains.
    """
    os.makedirs(save_path, exist_ok=True)
    
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    
    # Low-pass time domain
    ax = axes[0, 0]
    ax.stem(range(len(lp_coeffs)), lp_coeffs)
    ax.set_xlabel('Tap Index')
    ax.set_ylabel('Coefficient Value')
    ax.set_title('Low-Pass FIR Coefficients (Time Domain)')
    ax.grid(True, alpha=0.3)
    
    # High-pass time domain
    ax = axes[0, 1]
    ax.stem(range(len(hp_coeffs)), hp_coeffs)
    ax.set_xlabel('Tap Index')
    ax.set_ylabel('Coefficient Value')
    ax.set_title('High-Pass FIR Coefficients (Time Domain)')
    ax.grid(True, alpha=0.3)
    
    # Frequency response - magnitude
    n_fft = 1024
    ax = axes[1, 0]
    freq = np.linspace(0, 1, n_fft)
    
    # Compute magnitude responses
    lp_fft = np.abs(np.fft.fft(lp_coeffs, n_fft))
    hp_fft = np.abs(np.fft.fft(hp_coeffs, n_fft))
    
    ax.plot(freq, 20 * np.log10(lp_fft + 1e-10), label='Low-Pass', linewidth=2)
    ax.plot(freq, 20 * np.log10(hp_fft + 1e-10), label='High-Pass', linewidth=2)
    ax.set_xlabel('Normalized Frequency')
    ax.set_ylabel('Magnitude (dB)')
    ax.set_title('Frequency Response (Magnitude)')
    ax.legend()
    ax.grid(True, alpha=0.3)
    ax.set_ylim(-80, 10)
    
    # Frequency response - phase
    ax = axes[1, 1]
    lp_phase = np.angle(np.fft.fft(lp_coeffs, n_fft))
    hp_phase = np.angle(np.fft.fft(hp_coeffs, n_fft))
    
    ax.plot(freq, np.unwrap(lp_phase), label='Low-Pass', linewidth=2)
    ax.plot(freq, np.unwrap(hp_phase), label='High-Pass', linewidth=2)
    ax.set_xlabel('Normalized Frequency')
    ax.set_ylabel('Phase (radians)')
    ax.set_title('Frequency Response (Phase)')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(os.path.join(save_path, 'fir_coefficients.png'), dpi=150, bbox_inches='tight')
    plt.close()
    
    print(f"  Saved coefficient plots to {save_path}/fir_coefficients.png")

def plot_signals(input_signal, lp_output, hp_output, sample_rate, save_path, n_plot=1000):
    """
    Plot input and filtered signals.
    """
    os.makedirs(save_path, exist_ok=True)
    
    fig, axes = plt.subplots(3, 1, figsize=(14, 10))
    
    t = np.arange(n_plot) / sample_rate
    
    # Input signal
    ax = axes[0]
    ax.plot(t, input_signal[:n_plot], linewidth=0.5)
    ax.set_xlabel('Time (s)')
    ax.set_ylabel('Amplitude')
    ax.set_title('Input Signal (First 1000 Samples)')
    ax.grid(True, alpha=0.3)
    
    # Low-pass output
    ax = axes[1]
    ax.plot(t, lp_output[:n_plot], linewidth=0.5, color='green')
    ax.set_xlabel('Time (s)')
    ax.set_ylabel('Amplitude')
    ax.set_title('Low-Pass Filtered Output (First 1000 Samples)')
    ax.grid(True, alpha=0.3)
    
    # High-pass output
    ax = axes[2]
    ax.plot(t, hp_output[:n_plot], linewidth=0.5, color='red')
    ax.set_xlabel('Time (s)')
    ax.set_ylabel('Amplitude')
    ax.set_title('High-Pass Filtered Output (First 1000 Samples)')
    ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(os.path.join(save_path, 'fir_signals.png'), dpi=150, bbox_inches='tight')
    plt.close()
    
    print(f"  Saved signal plots to {save_path}/fir_signals.png")

def plot_spectra(input_signal, lp_output, hp_output, sample_rate, save_path, n_plot=1000):
    """
    Plot frequency spectra of signals.
    """
    os.makedirs(save_path, exist_ok=True)
    
    fig, axes = plt.subplots(2, 1, figsize=(14, 10))
    
    n_fft = 2048
    
    # Compute spectra
    input_fft = np.abs(np.fft.fft(input_signal[:n_plot], n_fft))
    lp_fft = np.abs(np.fft.fft(lp_output[:n_plot], n_fft))
    hp_fft = np.abs(np.fft.fft(hp_output[:n_plot], n_fft))
    
    freq = np.linspace(0, sample_rate/2, n_fft//2)
    
    # Linear scale
    ax = axes[0]
    ax.plot(freq, 20 * np.log10(input_fft[:n_fft//2] + 1e-10), label='Input', alpha=0.7)
    ax.plot(freq, 20 * np.log10(lp_fft[:n_fft//2] + 1e-10), label='Low-Pass', linewidth=2)
    ax.plot(freq, 20 * np.log10(hp_fft[:n_fft//2] + 1e-10), label='High-Pass', linewidth=2)
    ax.set_xlabel('Frequency (Hz)')
    ax.set_ylabel('Magnitude (dB)')
    ax.set_title('Frequency Spectra (Linear Scale)')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # Mark cutoff frequencies
    ax.axvline(x=5000, color='green', linestyle='--', alpha=0.5, label='LP Cutoff (5kHz)')
    ax.axvline(x=1000, color='red', linestyle='--', alpha=0.5, label='HP Cutoff (1kHz)')
    
    # Log scale
    ax = axes[1]
    ax.semilogx(freq, 20 * np.log10(input_fft[:n_fft//2] + 1e-10), label='Input', alpha=0.7)
    ax.semilogx(freq, 20 * np.log10(lp_fft[:n_fft//2] + 1e-10), label='Low-Pass', linewidth=2)
    ax.semilogx(freq, 20 * np.log10(hp_fft[:n_fft//2] + 1e-10), label='High-Pass', linewidth=2)
    ax.set_xlabel('Frequency (Hz)')
    ax.set_ylabel('Magnitude (dB)')
    ax.set_title('Frequency Spectra (Log Scale)')
    ax.legend()
    ax.grid(True, alpha=0.3)
    ax.set_ylim(-80, 60)
    
    plt.tight_layout()
    plt.savefig(os.path.join(save_path, 'fir_spectra.png'), dpi=150, bbox_inches='tight')
    plt.close()
    
    print(f"  Saved spectrum plots to {save_path}/fir_spectra.png")

def plot_error_analysis(input_signal, lp_output, hp_output, sample_rate, save_path):
    """
    Compare Q15 fixed-point output with float reference.
    """
    os.makedirs(save_path, exist_ok=True)
    
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    
    # Convert to float for comparison (use 'valid' mode)
    lp_float = fir_filter_float(input_signal, generate_fir_coefficients(N_TAP, CUTOFF_FREQ/SAMPLE_RATE, 'lowpass'), mode='valid')
    hp_float = fir_filter_float(input_signal, generate_fir_coefficients(N_TAP, CUTOFF_HP/SAMPLE_RATE, 'highpass'), mode='valid')
    
    # Error calculation
    lp_error = np.abs(lp_output.astype(np.int32) - lp_float[:len(lp_output)] * 32767)
    hp_error = np.abs(hp_output.astype(np.int32) - hp_float[:len(hp_output)] * 32767)
    
    # Low-pass error histogram
    ax = axes[0, 0]
    ax.hist(lp_error, bins=50, edgecolor='black', alpha=0.7)
    ax.set_xlabel('Absolute Error (LSB)')
    ax.set_ylabel('Count')
    ax.set_title(f'Low-Pass Error Distribution\nMax: {lp_error.max()}, Mean: {lp_error.mean():.2f}')
    ax.grid(True, alpha=0.3)
    
    # High-pass error histogram
    ax = axes[0, 1]
    ax.hist(hp_error, bins=50, edgecolor='black', alpha=0.7)
    ax.set_xlabel('Absolute Error (LSB)')
    ax.set_ylabel('Count')
    ax.set_title(f'High-Pass Error Distribution\nMax: {hp_error.max()}, Mean: {hp_error.mean():.2f}')
    ax.grid(True, alpha=0.3)
    
    # Error over time
    ax = axes[1, 0]
    ax.plot(lp_error[:1000], linewidth=0.5)
    ax.set_xlabel('Sample')
    ax.set_ylabel('Absolute Error (LSB)')
    ax.set_title('Low-Pass Error Over Time (First 1000 Samples)')
    ax.grid(True, alpha=0.3)
    
    ax = axes[1, 1]
    ax.plot(hp_error[:1000], linewidth=0.5)
    ax.set_xlabel('Sample')
    ax.set_ylabel('Absolute Error (LSB)')
    ax.set_title('High-Pass Error Over Time (First 1000 Samples)')
    ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(os.path.join(save_path, 'fir_error_analysis.png'), dpi=150, bbox_inches='tight')
    plt.close()
    
    print(f"  Saved error analysis to {save_path}/fir_error_analysis.png")
    
    return lp_error, hp_error

# ============================================================================
# Main
# ============================================================================
def main():
    print("=" * 60)
    print("FPGA-Friendly FIR Filter Generator")
    print("=" * 60)
    
    # Create output directories
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    os.makedirs(PLOT_DIR, exist_ok=True)
    os.makedirs(READMEM_DIR, exist_ok=True)
    
    # Step 1: Generate FIR coefficients
    print("\n[1/8] Generating FIR coefficients...")
    cutoff_norm_lp = CUTOFF_FREQ / SAMPLE_RATE
    cutoff_norm_hp = CUTOFF_HP / SAMPLE_RATE
    
    lp_coeffs_float = generate_fir_coefficients(N_TAP, cutoff_norm_lp, 'lowpass')
    hp_coeffs_float = generate_fir_coefficients(N_TAP, cutoff_norm_hp, 'highpass')
    lp_coeffs_q15 = quantize_to_q15(lp_coeffs_float)
    hp_coeffs_q15 = quantize_to_q15(hp_coeffs_float)
    
    print(f"  Low-pass taps: {len(lp_coeffs_float)}")
    print(f"  High-pass taps: {len(hp_coeffs_float)}")
    print(f"  Q15 scale factor: {Q15_SCALE}")
    
    # Step 2: Generate test signal
    print("\n[2/8] Generating test signal...")
    signal_float = generate_test_signal(N_SAMPLES, SAMPLE_RATE)
    signal_int16 = float_to_int16(signal_float)
    
    print(f"  Samples: {N_SAMPLES}")
    print(f"  Duration: {DURATION} seconds")
    print(f"  Sample rate: {SAMPLE_RATE} Hz")
    
    # Step 3: Apply FIR filters
    print("\n[3/8] Applying FIR filters (manual implementation)...")
    print("  Mode: 'valid' (FPGA-style, output = N - M + 1)")
    lp_output = fir_filter_manual(signal_int16, lp_coeffs_q15, mode='valid')
    hp_output = fir_filter_manual(signal_int16, hp_coeffs_q15, mode='valid')
    
    print(f"  Low-pass output: {len(lp_output)} samples")
    print(f"  High-pass output: {len(hp_output)} samples")
    
    # Step 4: Save numpy arrays
    print("\n[4/8] Saving numpy arrays...")
    np.save(os.path.join(OUTPUT_DIR, 'fir_lp_coeffs_q15.npy'), lp_coeffs_q15)
    np.save(os.path.join(OUTPUT_DIR, 'fir_hp_coeffs_q15.npy'), hp_coeffs_q15)
    np.save(os.path.join(OUTPUT_DIR, 'fir_input_int16.npy'), signal_int16)
    np.save(os.path.join(OUTPUT_DIR, 'fir_lp_output.npy'), lp_output)
    np.save(os.path.join(OUTPUT_DIR, 'fir_hp_output.npy'), hp_output)
    
    print(f"  Saved to {OUTPUT_DIR}/")
    
    # Step 5: Generate SystemVerilog readmem files
    print("\n[5/8] Generating SystemVerilog readmem files...")
    
    # For Verilog simulation: use N_SIM_SAMPLES input → N_SIM_OUTPUT output
    print(f"  Input samples for simulation: {N_SIM_SAMPLES}")
    print(f"  Expected output (N_SIM_SAMPLES - N_TAP + 1): {N_SIM_OUTPUT}")
    
    # Generate signal for Verilog simulation (only first N_SIM_SAMPLES samples)
    signal_sim_float = generate_test_signal(N_SIM_SAMPLES, SAMPLE_RATE)
    signal_sim_int16 = float_to_int16(signal_sim_float)
    
    # Apply FIR filter to simulation signal
    lp_output_sim = fir_filter_manual(signal_sim_int16, lp_coeffs_q15, mode='valid')
    hp_output_sim = fir_filter_manual(signal_sim_int16, hp_coeffs_q15, mode='valid')
    
    print(f"  LP output samples: {len(lp_output_sim)}")
    print(f"  HP output samples: {len(hp_output_sim)}")
    
    # Write input signal for Verilog simulation
    write_readmem_file(
        os.path.join(READMEM_DIR, 'input_signal.mem'),
        signal_sim_int16
    )
    
    # Write expected outputs (should be N_SIM_OUTPUT samples)
    write_readmem_file(
        os.path.join(READMEM_DIR, 'lp_coeffs.mem'),
        lp_coeffs_q15
    )
    write_readmem_file(
        os.path.join(READMEM_DIR, 'hp_coeffs.mem'),
        hp_coeffs_q15
    )
    write_readmem_file(
        os.path.join(READMEM_DIR, 'lp_output_expected.mem'),
        lp_output_sim
    )
    write_readmem_file(
        os.path.join(READMEM_DIR, 'hp_output_expected.mem'),
        hp_output_sim
    )
    
    # Also save full output for reference
    write_readmem_file(
        os.path.join(READMEM_DIR, 'lp_output_full.mem'),
        lp_output
    )
    write_readmem_file(
        os.path.join(READMEM_DIR, 'hp_output_full.mem'),
        hp_output
    )
    
    # Step 6: Generate plots
    print("\n[6/8] Generating coefficient plots...")
    plot_coefficients(lp_coeffs_q15, hp_coeffs_q15, PLOT_DIR)
    
    print("\n[7/8] Generating signal plots...")
    plot_signals(signal_sim_float, lp_output_sim.astype(np.float64)/32767, 
                hp_output_sim.astype(np.float64)/32767, SAMPLE_RATE, PLOT_DIR, N_SIM_OUTPUT)
    
    print("\n[8/8] Generating spectrum plots...")
    plot_spectra(signal_sim_float, lp_output_sim.astype(np.float64)/32767,
                 hp_output_sim.astype(np.float64)/32767, SAMPLE_RATE, PLOT_DIR, N_SIM_OUTPUT)
    
    # Error analysis
    print("\nBonus: Error analysis...")
    lp_error, hp_error = plot_error_analysis(signal_sim_float, lp_output_sim, hp_output_sim, SAMPLE_RATE, PLOT_DIR)
    
    # Summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"\nFilter Specifications:")
    print(f"  - Number of taps: {N_TAP}")
    print(f"  - Sample rate: {SAMPLE_RATE} Hz")
    print(f"  - Signal duration: {DURATION} seconds")
    print(f"  - Low-pass cutoff: {CUTOFF_FREQ} Hz")
    print(f"  - High-pass cutoff: {CUTOFF_HP} Hz")
    print(f"  - Q15 scale factor: {Q15_SCALE}")
    
    print(f"\nQuantization Error:")
    print(f"  - Low-pass max error: {lp_error.max()} LSB")
    print(f"  - Low-pass mean error: {lp_error.mean():.2f} LSB")
    print(f"  - High-pass max error: {hp_error.max()} LSB")
    print(f"  - High-pass mean error: {hp_error.mean():.2f} LSB")
    
    print(f"\nOutput Files:")
    print(f"  - Numpy arrays: {OUTPUT_DIR}/")
    print(f"  - Plots: {PLOT_DIR}/")
    print(f"  - Verilog files: {READMEM_DIR}/")
    print(f"  - Input samples for Verilog sim: {N_SIM_SAMPLES}")
    print(f"  - Expected output samples: {N_SIM_OUTPUT} ({N_SIM_SAMPLES}-{N_TAP}+1)")

if __name__ == "__main__":
    main()
