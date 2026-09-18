import Accelerate

/// FFT-based cross-correlation `c[τ] = Σ_{j<W} a[j] · b[j + τ]` for `τ = 0 ..< lagCount`.
///
/// Evaluating all lags directly costs `O(W · lags)`; going through the frequency domain costs
/// `O(N log N)` with `N` the next power of two ≥ `b.count`, which is roughly an order of magnitude
/// less work for the window sizes used by the tuner and keeps the CPU (and battery) footprint tiny.
///
/// The type owns an `FFTSetup` and scratch memory, so it is a reference type confined to one
/// isolation domain (it is deliberately **not** `Sendable`).
final class CrossCorrelator {
    /// Transform length (power of two).
    let size: Int

    private let half: Int
    private let log2n: vDSP_Length
    private let setup: FFTSetup
    private let aReal: UnsafeMutablePointer<Float>
    private let aImag: UnsafeMutablePointer<Float>
    private let bReal: UnsafeMutablePointer<Float>
    private let bImag: UnsafeMutablePointer<Float>

    /// - Parameter minimumSize: smallest acceptable transform length; rounded up to a power of two.
    init?(minimumSize: Int) {
        guard minimumSize >= 16, minimumSize <= 1 << 20 else { return nil }
        let log2n = vDSP_Length(Int.bitWidth - (minimumSize - 1).leadingZeroBitCount)
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return nil }
        self.log2n = log2n
        self.size = 1 << Int(log2n)
        self.half = size / 2
        self.setup = setup
        aReal = .allocate(capacity: half)
        aImag = .allocate(capacity: half)
        bReal = .allocate(capacity: half)
        bImag = .allocate(capacity: half)
    }

    deinit {
        vDSP_destroy_fftsetup(setup)
        aReal.deallocate()
        aImag.deallocate()
        bReal.deallocate()
        bImag.deallocate()
    }

    /// Computes the first `lagCount` correlation lags.
    /// - Precondition: `a.count ≤ size`, `b.count ≤ size`, `lagCount ≤ size`.
    func correlate(_ a: [Float], _ b: [Float], lagCount: Int, into output: inout [Double]) {
        precondition(a.count <= size && b.count <= size && lagCount <= size)

        pack(a, real: aReal, imag: aImag)
        pack(b, real: bReal, imag: bImag)

        var splitA = DSPSplitComplex(realp: aReal, imagp: aImag)
        var splitB = DSPSplitComplex(realp: bReal, imagp: bImag)
        vDSP_fft_zrip(setup, &splitA, 1, log2n, FFTDirection(kFFTDirection_Forward))
        vDSP_fft_zrip(setup, &splitB, 1, log2n, FFTDirection(kFFTDirection_Forward))

        // conj(A) · B per bin. Packed format: bin 0 holds DC in `real[0]` and Nyquist in `imag[0]`,
        // both purely real, so they are multiplied separately.
        let dc = aReal[0] * bReal[0]
        let nyquist = aImag[0] * bImag[0]
        for k in 1..<half {
            let ar = aReal[k], ai = aImag[k], br = bReal[k], bi = bImag[k]
            aReal[k] = ar * br + ai * bi
            aImag[k] = ar * bi - ai * br
        }
        aReal[0] = dc
        aImag[0] = nyquist

        vDSP_fft_zrip(setup, &splitA, 1, log2n, FFTDirection(kFFTDirection_Inverse))

        // vDSP's packed real transform doubles each forward result (×2 for A and ×2 for B) and the
        // unnormalised inverse multiplies by N: undo both.
        let scale = 1 / Float(4 * size)
        for lag in 0..<lagCount {
            let value = lag.isMultiple(of: 2) ? aReal[lag / 2] : aImag[lag / 2]
            output[lag] = Double(value * scale)
        }
    }

    /// Writes even samples to `real`, odd samples to `imag`, zero-padding up to `size`.
    private func pack(_ samples: [Float], real: UnsafeMutablePointer<Float>, imag: UnsafeMutablePointer<Float>) {
        real.update(repeating: 0, count: half)
        imag.update(repeating: 0, count: half)
        samples.withUnsafeBufferPointer { source in
            for index in 0..<source.count {
                if index.isMultiple(of: 2) {
                    real[index / 2] = source[index]
                } else {
                    imag[index / 2] = source[index]
                }
            }
        }
    }
}
