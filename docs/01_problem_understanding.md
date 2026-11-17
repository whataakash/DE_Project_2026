# Phase 1: Problem understanding

**Product goal:** Build a regular learning habit. Proposed **North Star metric:** weekly learners completing lessons; supporting metrics include speed, completion and retention. These are goals, not measured results.

**ICP and segments:** Our assumed **ideal customer profile (ICP)** is an India-focused learner seeking short, regular language practice. Segment by lifecycle (new, active, returning, at risk), plan (Free, Super, Max), course and device. Internal users include curriculum, gamification, growth, notifications, monetisation and support teams.

| Problem / queries | Business need in simple words | Stakeholders / segments | Classification and product lens |
|---|---|---|---|
| **P1: Slow home screen** — R01–R04, R06 | Show courses, XP, goals, streak and the next lesson quickly so learners can start practising. | New, active and returning learners; learner-app team. | **Customer-facing / real-time.** Activation and engagement: track time to start and home-to-lesson conversion. |
| **P2: Slow leagues** — R05, R14, W04 | Make leaderboards responsive and publish correct weekly rankings, promotions and demotions on time. | Competitive learners; leagues/gamification team. | **Mixed:** real-time leaderboard, analytics reports, batch weekly close. Retention: track leaderboard latency and on-time closure. |
| **P3: Slow lesson updates** — W01–W03 | Start lessons, save completions and update XP immediately. Reliable progress builds trust and supports continued practice. | All practising learners; learner-app team. | **Customer-facing / real-time.** Core learning journey: track save latency, write failures and lesson completion rate. |
| **P4: Slow curriculum reports** — R07, R08, R19, R24 | Find lessons where learners make mistakes, lose hearts or quit, so content designers can improve them. | Curriculum team; learners struggling with particular lessons or levels. | **Reporting / analytics.** Learning quality: track quit rate, mistakes and completions by lesson. |
| **P5: Empty referral audience** — R13 | Correctly identify learners who have never referred anyone, so growth can select an eligible referral audience. | Growth team; learners with no referrals. | **Interactive tool / reporting.** AARRR referral stage: validate audience correctness before measuring referral conversion. |
| **P6: Dashboards time out** — R09, R15, R18, R20, R21, R25 | Make daily activity, cohort retention, XP trends, course popularity and reminder audiences available for decisions. | Growth, retention and notifications teams; new, retained and at-risk learners. | **Mostly reporting / analytics;** reminder selection is interactive. AARRR retention: track DAU, cohort retention and report latency. |
| **P7: Platform slows with growth** — R10–R12, R16–R17, R22–R23, W05 | Support 20× activity while keeping sign-in, friend search, badges, support tools and paid-plan insights dependable. | All learners and plan segments; platform, monetisation and support teams. | **Mixed:** real-time sign-in/profile, interactive search/support, analytics and batch badges. Track latency by journey and segment. |

**Frameworks:** AARRR means Acquisition, Activation, Retention, Referral and Revenue. Apply its relevant stages above; group learners by signup period for cohort retention. DAU means daily active users.

**Assumptions:** ICP/segments are hypotheses, not validated research. Query IDs define scope; mixed problems need separate performance targets. Faster queries may support retention/revenue but do not prove gains. Missing completion/referral fields can be valid. Phase 2 verifies data rules; Phase 3 measures baseline performance before optimisation.
