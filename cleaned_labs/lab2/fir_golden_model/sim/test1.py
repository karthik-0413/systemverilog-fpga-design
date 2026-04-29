import numpy as np
import time
from pynq import Overlay, MMIO, allocate

ol = Overlay("/home/xilinx/overlays/lab2/part3/lab2_overlay.bit")
print("Bitstream Uploaded")

# GPIO via raw MMIO
gpio_base = ol.ip_dict['axi_gpio_0']['phys_addr']
gpio_mmio = MMIO(gpio_base, 0x10000)

dma_send = ol.axi_dma_0.sendchannel
dma_recv = ol.axi_dma_0.recvchannel

def load_hex_file(filename):
    with open(filename, 'r') as f:
        return np.array([int(line.strip(), 16) for line in f if line.strip()], dtype=np.int16)

input_data = load_hex_file('input_signal.txt')
lp_coeffs = load_hex_file('lp_coeffs.txt')
lp_expected = load_hex_file('lp_output_expected.txt')

# Allocate 32-bit buffers so each sample = one AXI-Stream beat
input_buffer = allocate(shape=(1000,), dtype=np.int32)
output_buffer = allocate(shape=(937,), dtype=np.int32)
coeff_buffer = allocate(shape=(64,), dtype=np.int32)
coeff_echo_buffer = allocate(shape=(64,), dtype=np.int32)

# Sign-extend 16-bit to 32-bit
input_buffer[:] = input_data.astype(np.int32)


# ========================================
# Step 1: Load LP Coefficients
# ========================================
print("Loading LP coefficients...")
gpio_mmio.write(0x00, 0x1)  # Enable coeff load mode
time.sleep(0.01)  # Let GPIO propagate before DMA starts
print(f"GPIO after enable: {hex(gpio_mmio.read(0x00))}")

coeff_buffer[:] = lp_coeffs.astype(np.int32)
coeff_echo_buffer[:] = 0

dma_send.transfer(coeff_buffer)
dma_recv.transfer(coeff_echo_buffer)
dma_send.wait()
dma_recv.wait()

echo_match = np.array_equal(coeff_echo_buffer[:64] & 0xFFFF, lp_coeffs.astype(np.int32) & 0xFFFF)
print(f"Coeff echo match: {echo_match}")
if not echo_match:
    print("First 10 echo values:")
    for i in range(min(10, 64)):
        print(f"  [{i}] sent 0x{lp_coeffs[i] & 0xFFFF:04x}, echo 0x{coeff_echo_buffer[i] & 0xFFFF:04x}")

# ========================================
# Step 2: Process Data
# ========================================
print("Processing data...")
gpio_mmio.write(0x00, 0x0)  # Normal filtering mode
time.sleep(0.01)  # Let GPIO propagate before DMA starts

dma_send.transfer(input_buffer)
dma_recv.transfer(output_buffer)
dma_send.wait()
dma_recv.wait()

# ========================================
# Check Results
# ========================================
# Compare lower 16 bits of output
output_16 = (output_buffer & 0xFFFF).astype(np.int16)
matches = np.sum(output_16 == lp_expected)
print(f"LP Filter: {matches}/937 samples match")
if matches == 937:
    print("LP Filter PASSED!")
else:
    print(f"LP Filter FAILED - {937 - matches} mismatches")
    print("First 10 mismatches:")
    count = 0
    for i in range(937):
        if output_16[i] != lp_expected[i]:
            print(f"  [{i}] got 0x{output_16[i] & 0xFFFF:04x}, expected 0x{lp_expected[i] & 0xFFFF:04x} (raw32: 0x{output_buffer[i] & 0xFFFFFFFF:08x})")
            count += 1
            if count >= 10:
                break