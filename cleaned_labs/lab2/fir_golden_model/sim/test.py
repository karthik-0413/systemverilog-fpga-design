import numpy as np

# load fixed-point coefficients
hp = np.fromfile("hp_coeffs.mem", dtype=np.int16)

# convert to float
hp_f = hp / 32768.0

# convolve with input signal
y = np.convolve(input_signal, hp_f)

# quantize same way as DUT
y_q = np.round(y * 32768).astype(np.int16)
