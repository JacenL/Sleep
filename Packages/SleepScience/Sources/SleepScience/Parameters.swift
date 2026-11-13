import Foundation

/// Published parameters of the three-process model of alertness, as implemented
/// in v1 (docs/SCIENCE.md section 4). Every value here was checked against the
/// cited source on 2026-11-13. Nothing in this file is a display convention;
/// those live in `DisplayConventions`.
///
/// Sources, abbreviated below:
/// - "2004": Åkerstedt, Folkard & Portin, Aviat Space Environ Med 2004;75(3 Suppl):A75–83.
/// - "2008": Åkerstedt et al., Chronobiol Int 2008;25(2):309–319.
/// - "Ingre": Ingre et al., PLoS One 2014;9(10):e108679, equations 1.1–1.8.
/// - "1995": Åkerstedt & Folkard, in Vigilance et transports, PUL 1995:199–206.
public struct ThreeProcessParameters: Sendable, Equatable {
    /// Upper asymptote of S. 2004 p.A76 ("U upper asymptote (14.3)"); Ingre ("ha = 14.3").
    public var upperAsymptote: Double = 14.3
    /// Lower asymptote of S. 2004 p.A76 ("L lower asymptote (2.4)"); Ingre ("la = 2.4").
    public var lowerAsymptote: Double = 2.4
    /// Rate of decay of S while awake, per hour. 2004 p.A76 ("e^(−0.0353t)"); Ingre eq 1.1 ("d = −0.0353").
    public var wakeDecayRate: Double = -0.0353

    /// S at sleep onset in the definition of the recovery rate g. Ingre: g = log((ha − 14.0)/(ha − 7.96))/8;
    /// 2004 p.A76 gives 7.96 as the default "value of S at retiring".
    public var recoveryDefinitionStart: Double = 7.96
    /// S reached after a full habitual night in the definition of g. Ingre (see `recoveryDefinitionStart`);
    /// 2004 p.A76 gives 14 as the default "value of S at awakening".
    public var recoveryDefinitionEnd: Double = 14.0

    /// Breakpoint below which recovery during sleep is linear (the "brake"). 2008 abstract
    /// ("12.2 on the 1-21 unit scale"); Ingre eqs 1.3–1.5 ("bl = 12.2"). 2004 used 12.5.
    public var brakePoint: Double = 12.2
    /// Whether the brake applies. On in v1 (decision D1, 2026-11-13). Off only reproduces the
    /// original exponential recovery (Ingre eq 1.2) for golden test 7.
    public var brakeEnabled: Bool = true

    /// Circadian mesor. Ingre eq 1.7 ("Cm = 0").
    public var circadianMesor: Double = 0
    /// Circadian amplitude. Ingre eq 1.7 ("Ca = 2.5"); 2004 p.A76 ("M amplitude (2.5)").
    public var circadianAmplitude: Double = 2.5
    /// Default circadian acrophase, in hours of local clock time. Ingre ("default circadian phase (p = 16.8)").
    /// The 2004 paper gives no default value.
    public var defaultAcrophaseHours: Double = 16.8

    /// 12 h component mesor. Ingre eq 1.8 ("Um = −.5").
    public var ultradianMesor: Double = -0.5
    /// 12 h component amplitude. Ingre eq 1.8 ("Ua = .5"); 2004 p.A77 ("amplitude of 0.5 units").
    public var ultradianAmplitude: Double = 0.5
    /// Offset of the 12 h component from the circadian acrophase, in hours: U = Um + Ua·cos(2π(h − p − 3)/12).
    /// Ingre eq 1.8. The 2004 form, mesor − Mu·cos(2π/12·(t − (p − 3))), is the same curve.
    public var ultradianPhaseOffsetHours: Double = 3

    /// Whether sleep inertia W is added to A. Off in v1 (decision D2, 2026-11-13): 2004 p.A76 says W is
    /// "presently excluded", and Ingre found adding W worsened fit ("default parameters of process W were exaggerated").
    public var includeSleepInertia: Bool = false
    /// Initial magnitude of sleep inertia. Ingre eq 1.6 ("Wc = −5.72"); 2004 p.A76 gives 5.7, subtracted.
    public var inertiaMagnitude: Double = -5.72
    /// Recovery rate of sleep inertia, per hour. Ingre eq 1.6 ("Wd = −1.51"). 2004 prints 0.65692, which is
    /// 1.51/ln 10; Ingre's natural-log value is used.
    public var inertiaDecayRate: Double = -1.51

    /// Level on the 1–21 scale at which predicted sleepiness becomes a risk: "'7' to a sleepiness threshold
    /// (EOG slow eye movements)", 2004 p.A77; also 1995.
    public var sleepinessThreshold: Double = 7

    /// Bottom of the model's output scale: "The scale of the model ranges normally from 1–21", 2004 p.A77.
    public var scaleMinimum: Double = 1

    public init() {}

    /// The values verified for v1.
    public static let published = ThreeProcessParameters()

    /// Recovery rate g for a habitual sleep need of `sleepNeedHours`, per hour. The model handles sleep need
    /// "by adjusting the time constant of the S function to reach full recovery in the time indicated as
    /// habitual sleep duration. The default value is 8 h" (2004 p.A78; decision D3). g(8) ≈ −0.3813.
    public func sleepRecoveryRate(sleepNeedHours: Double) -> Double {
        log((upperAsymptote - recoveryDefinitionEnd) / (upperAsymptote - recoveryDefinitionStart)) / sleepNeedHours
    }
}
