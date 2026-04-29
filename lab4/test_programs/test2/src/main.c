
// Testing JALR
int summie(int a, int b) {
    return a + b;
}

void main() {
    int final_result = 0;

    // ****************************************
    // --- Shift tests ---
    // ****************************************
    int a = 1;
    a = a << 3;        // SLL: 1 << 3 = 8
    final_result = final_result + a;      // Updated final_result = 8

    a = 64;
    a = a >> 3;         // SRL: 64 >> 3 = 8
    final_result = final_result + a;      // Updated final_result = 16

    a = -128;
    a = a >> 2;         // SRA: -128 >> 2 = -32 (arithmetic)
    final_result = final_result + a;      // Updated final_result = -16

    // ****************************************
    // --- Branch tests ---
    // ****************************************
    int b = 5;
    int c = -2;
    unsigned int temp1 = b;
    unsigned int temp2 = c;

    // BNE
    if (b != c) {
        final_result = summie(final_result, 1);    // Updated final_result = -15
    }

    // BLT
    if (c < b) {
        final_result = summie(final_result, 1);    // Updated final_result = -14
    }

    // BGE
    if (b >= c) {
        final_result = summie(final_result, 1);    // Updated final_result = -13
    }

    // BLTU
    if (temp1 < temp2) {
        final_result = summie(final_result, 1);    // Updated final_result = -12
    }

    // BGEU
    if (temp2 >= temp1) {
        final_result = summie(final_result, 1);    // Updated final_result = -11
    }

    // ****************************************
    // --- Bitwise tests ---
    // ****************************************
    int d = 0xFAB4;
    int e = 0x04CD;
    final_result = final_result + (d & e);  // Updated final_result = 121
    final_result = final_result + (d | e);  // Updated final_result = 65277 + 119 = 65398
    final_result = final_result + (d ^ e);  // Updated final_result = 65346 + 65145 = 130543

    // ****************************************
    // --- Load/Store tests ---
    // ****************************************
    int temp_arr[4] = {1, 2, 3, 4};
    final_result = final_result + temp_arr[0] + temp_arr[1] + temp_arr[2] + temp_arr[3]; // Updated final_result = 130553

    // ****************************************
    // Store final result
    // ****************************************
    int *ptr = (int *)(4096 - 4);
    *ptr = final_result;

    while(1);
    return;
}