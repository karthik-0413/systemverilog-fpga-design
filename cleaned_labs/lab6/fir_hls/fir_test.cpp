#include "fir.h"

using namespace std;

int main() {

    hls::stream<packet> in_stream, out_stream;
    packet tmp_in, tmp_out;

    // Open data files copied from fir_golden/
    ifstream fin("input.txt");
    ifstream fgolden("golden.txt");

    if (!fin.is_open()) {
        cerr << "ERROR: cannot open input.txt" << endl;
        return 1;
    }
    if (!fgolden.is_open()) {
        cerr << "ERROR: cannot open golden.txt" << endl;
        return 1;
    }

    int errors = 0;

    for (int i = 0; i < NUM_SAMPLES; i++) {

        int x_val, gold_val;
        fin     >> x_val;
        fgolden >> gold_val;

        tmp_in.data = x_val;
        tmp_in.keep = -1;
        tmp_in.strb  = 1;
        tmp_in.user  = 1;
        tmp_in.last  = (i == NUM_SAMPLES - 1) ? 1 : 0;

        in_stream.write(tmp_in);
        fir(in_stream, out_stream);
        out_stream.read(tmp_out);

        int y_val = tmp_out.data.to_int();

        cout << "sample[" << i << "]: in=" << x_val
             << "  got=" << y_val
             << "  expected=" << gold_val;

        if (y_val != gold_val) {
            cout << "  <-- MISMATCH";
            errors++;
        }
        cout << endl;
    }

    fin.close();
    fgolden.close();

    if (errors == 0) {
        cout << "\nSuccess: all " << NUM_SAMPLES << " samples match golden." << endl;
        return 0;
    } else {
        cout << "\nFAILED: " << errors << " mismatch(es)." << endl;
        return 1;
    }
}
