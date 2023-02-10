#include <iostream>
#include <omp.h>
#include <fstream>
#include <cassert>

using namespace std;

const int L = 256;
const int M = 4;

int main(int num_of_arguments, char *args[]) {
    assert("not 4 arguments" && num_of_arguments == 4);
    int num_of_threads;
    try {
        num_of_threads = stoi(args[1]);
    } catch (...) {
        cout << "number of threads is not a number";
        return 0;
    }
    assert("number of threads smaller then -1" && num_of_threads > -2);

    uint8_t *bytes;
    long long length;

    try {
        ifstream file(args[2], ios_base::binary);

        file.seekg(0, ifstream::end);
        length = file.tellg();
        file.seekg(0, ifstream::beg);

        bytes = new uint8_t[length];

        file.read((char*) bytes, length);
        file.close();
    } catch (...) {
        cout << "input error";
        return 0;
    }

    string type;
    type += (char) bytes[0];
    type += (char) bytes[1];
    type += (char) bytes[2];
    assert("no P5" && type == "P5\n");

    string width;
    int idx = 3;
    while (bytes[idx] != ' ') {
        assert("not number" && bytes[idx] >= '0' && bytes[idx] <= '9');
        width += (char) bytes[idx];
        idx++;
    }

    idx++;
    string height;
    while (bytes[idx] != '\n') {
        assert("not number" && bytes[idx] >= '0' && bytes[idx] <= '9');
        height += (char) bytes[idx];
        idx++;
    }

    idx++;
    string bright;
    while (bytes[idx] != '\n') {
        bright += (char) bytes[idx];
        idx++;
    }
    assert("not 255" && bright == "255");

    idx++;
    double time = 0;
    int f[3];

    int num_of_runs = 100;
    if (num_of_threads == -1) {

        for (int run_num = 0; run_num <= num_of_runs; run_num++) {
            double t = omp_get_wtime();

            int brights[256];
            for (int & i : brights) {
                i = 0;
            }

            for (int i = idx; i < length; i++) {
                brights[bytes[i]]++;
            }

            long long pref_p[256];
            pref_p[0] = brights[0];
            for (int i = 1; i < 256; i++) {
                pref_p[i] = pref_p[i - 1] + brights[i];
            }

            long long pref_m[256];
            pref_m[0] = 0;
            for (int i = 1; i < 256; i++) {
                pref_m[i] = pref_m[i - 1] + brights[i] * i;
            }

            double max_d = 0;

            double d;
            long long m1;
            long long m2;
            long long m3;
            long long m4;

            for (int f0 = 0; f0 < L - M + 1; f0++) {
                for (int f1 = f0 + 1; f1 < L - M + 2; f1++) {
                    for (int f2 = f1 + 1; f2 < L - M + 3; f2++) {
                        d = 0;
                        m1 = pref_m[f0];
                        d += (double) (m1 * m1) / (double) pref_p[f0];
                        m2 = pref_m[f1] - pref_m[f0];
                        d += (double) (m2 * m2) / (double) (pref_p[f1] - pref_p[f0]);
                        m3 = pref_m[f2] - pref_m[f1];
                        d += (double) (m3 * m3) / (double) (pref_p[f2] - pref_p[f1]);
                        m4 = pref_m[L - 1] - pref_m[f2];
                        d += (double) (m4 * m4) / (double) (pref_p[L - 1] - pref_p[f2]);

                        if (d > max_d) {
                            max_d = d;
                            f[0] = f0;
                            f[1] = f1;
                            f[2] = f2;
                        }
                    }
                }
            }

            for (int i = idx; i < length; i++) {
                if (run_num == num_of_runs) {
                    if (bytes[i] <= f[0]) {
                        bytes[i] = 0;
                    } else if (bytes[i] <= f[1]) {
                        bytes[i] = 84;
                    } else if (bytes[i] <= f[2]) {
                        bytes[i] = 170;
                    } else {
                        bytes[i] = 255;
                    }
                }
            }

            try {
                ofstream file2(args[3], ios_base::binary);
                file2.write((char*) bytes, length);
                file2.close();
            } catch (...) {
                cout << "output error";
                return 0;
            }

            double t1 = omp_get_wtime();
            time += (t1 - t);
        }

    } else {

        if (num_of_threads != 0) {
            omp_set_num_threads(num_of_threads);
        }

        for (int run_num = 1; run_num <= num_of_runs; run_num++) {
            double t = omp_get_wtime();

            int brights[256];
            for (int & i : brights) {
                i = 0;
            }

#pragma omp parallel
            {
                int brights_i[256];
                for (int & j : brights_i) {
                    j = 0;
                }
#pragma omp for nowait
                for (int i = idx; i < length; i++) {
                    brights_i[bytes[i]]++;
                }

#pragma omp critical
                for (int j = 0; j < 256; j++) {
                    brights[j] += brights_i[j];
                }
            }

            long long pref_p[256];
            pref_p[0] = brights[0];
            for (int i = 1; i < 256; i++) {
                pref_p[i] = pref_p[i - 1] + brights[i];
            }

            long long pref_m[256];
            pref_m[0] = 0;
            for (int i = 1; i < 256; i++) {
                pref_m[i] = pref_m[i - 1] + brights[i] * i;
            }

            double max_d = 0;


#pragma omp parallel
            {
                double max_d_i = 0;
                int fi[3];

                double d;
                long long m1;
                long long m2;
                long long m3;
                long long m4;


                for (int f0 = 0; f0 < L - M + 1; f0++) {
                    for (int f1 = f0 + 1; f1 < L - M + 2; f1++) {
#pragma omp for nowait
                        for (int f2 = f1 + 1; f2 < L - M + 3; f2++) {
                            m1 = pref_m[f0];
                            m2 = pref_m[f1] - pref_m[f0];
                            m3 = pref_m[f2] - pref_m[f1];
                            m4 = pref_m[L - 1] - pref_m[f2];

                            d = 0;
                            d += (double) (m1 * m1) / (double) pref_p[f0];
                            d += (double) (m2 * m2) / (double) (pref_p[f1] - pref_p[f0]);
                            d += (double) (m3 * m3) / (double) (pref_p[f2] - pref_p[f1]);
                            d += (double) (m4 * m4) / (double) (pref_p[L - 1] - pref_p[f2]);

                            if (d > max_d_i) {
                                max_d_i = d;
                                fi[0] = f0;
                                fi[1] = f1;
                                fi[2] = f2;
                            }
                        }
                    }
                }

#pragma omp critical
                if (max_d_i > max_d) {
                    max_d = max_d_i;
                    f[0] = fi[0];
                    f[1] = fi[1];
                    f[2] = fi[2];
                }

            }

#pragma omp parallel
            {
#pragma omp for
                for (int i = idx; i < length; i++) {
                    if (run_num == num_of_runs) {
                        if (bytes[i] <= f[0]) {
                            bytes[i] = 0;
                        } else if (bytes[i] <= f[1]) {
                            bytes[i] = 84;
                        } else if (bytes[i] <= f[2]) {
                            bytes[i] = 170;
                        } else {
                            bytes[i] = 255;
                        }
                    }
                }

            }

            try {
                ofstream file2(args[3], ios_base::binary);
                file2.write((char*) bytes, length);
                file2.close();
            } catch (...) {
                cout << "output error";
                return 0;
            }
            double t1 = omp_get_wtime();
            time += (t1 - t);
        }
    }
    printf("Time (%i thread(s)): %g ms\n", num_of_threads, time * 1000 / (float) num_of_runs);
    printf("%u %u %u\n", f[0], f[1], f[2]);
    delete[] bytes;
    return 0;
}
