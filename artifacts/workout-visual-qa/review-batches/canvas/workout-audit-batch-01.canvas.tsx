import {
  Button,
  Callout,
  CollapsibleSection,
  Divider,
  Grid,
  H1,
  H2,
  Link,
  Pill,
  Row,
  Select,
  Stack,
  Stat,
  Table,
  Text,
  TextInput,
  useCanvasAction,
  useCanvasState,
  useHostTheme,
} from "cursor/canvas";
import { useMemo } from "react";

type ReviewDecision = "pending" | "accept_as_is" | "script_fix" | "redraw" | "defer";

type ExerciseRow = {
  index: number;
  exerciseId: string;
  severity: "critical" | "major";
  findings: string[];
  issueTags: string[];
  suggestedRoute: string;
  auditJsonPath: string | null;
  maleContact: string;
  femaleContact: string;
  previewDir: string;
  sourceFrames: string[];
};

const BATCH = {
  "meta": {
    "batchNumber": 1,
    "exerciseCount": 50,
    "severityCounts": {
      "critical": 20,
      "major": 30
    },
    "issueTagCounts": {
      "background": 41,
      "framing": 28,
      "padding": 8,
      "clipping": 17,
      "anatomy": 14,
      "other": 1
    },
    "suggestedRouteCounts": {
      "script_fix": 33,
      "redraw": 16,
      "defer": 1
    },
    "generatedAt": "2026-09-04T23:51:41.927858+00:00",
    "workspaceRoot": "/Users/apoorvdarshan/fud-ai"
  },
  "exercises": [
    {
      "index": 1,
      "exerciseId": "Barbell_Glute_Bridge",
      "severity": "critical",
      "findings": [
        "All eight originals retain white/gray floor residue visible against dark backgrounds",
        "Male frames 1 and 2 show floating upper back/head rather than stable shoulder contact",
        "Sequence has scale and foot/head anchor drift",
        "female frame 3 does not precisely return to frame 0",
        "Artwork is positioned low with little bottom padding"
      ],
      "issueTags": [
        "background",
        "framing",
        "padding"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Barbell_Glute_Bridge/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Barbell_Glute_Bridge/Barbell_Glute_Bridge_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Barbell_Glute_Bridge/Barbell_Glute_Bridge_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Barbell_Glute_Bridge",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Glute_Bridge_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Glute_Bridge_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Glute_Bridge_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Glute_Bridge_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Glute_Bridge_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Glute_Bridge_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Glute_Bridge_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Glute_Bridge_female_v2_3.png"
      ]
    },
    {
      "index": 2,
      "exerciseId": "Barbell_Rear_Delt_Row",
      "severity": "critical",
      "findings": [
        "All eight originals contain cropped fragments of multiple poses instead of one complete exercise pose per frame.",
        "Male and female frames 0 and 3 omit most of the athlete",
        "frames 1 and 2 contain stacked clipped poses.",
        "Female frames 1 and 2 include stray shoe fragments at the top edge.",
        "White background remnants remain in some enclosed gaps.",
        "The original sequence cannot display coherent movement or stable complete anatomy."
      ],
      "issueTags": [
        "background",
        "clipping",
        "anatomy"
      ],
      "suggestedRoute": "redraw",
      "auditJsonPath": "audit-only/Barbell_Rear_Delt_Row/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Barbell_Rear_Delt_Row/Barbell_Rear_Delt_Row_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Barbell_Rear_Delt_Row/Barbell_Rear_Delt_Row_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Barbell_Rear_Delt_Row",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Rear_Delt_Row_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Rear_Delt_Row_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Rear_Delt_Row_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Rear_Delt_Row_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Rear_Delt_Row_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Rear_Delt_Row_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Rear_Delt_Row_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Rear_Delt_Row_female_v2_3.png"
      ]
    },
    {
      "index": 3,
      "exerciseId": "Bent_Over_One-Arm_Long_Bar_Row",
      "severity": "critical",
      "findings": [
        "Large opaque white/light patterned background islands remain between arms, torso and thighs in all frames",
        "female frames also retain white between the lower legs. These remain white against the dark preview.",
        "The pulling arm changes sides/contact through the sequence. Male 1 and female 1/3 show a raised empty fist while the other hand grips the lower bar. Male 2 grips a separate short black segment above the main shaft, with no visible connection. Female 2 has the raised fist separated from the bar while the other hand rests on the knee, leaving the raised bar unsupported. This breaks the one-arm row depiction.",
        "An extra downward hand/finger shape appears beneath the hand gripping the bar at the knee, while a separate bent arm ends in a fist at the waist",
        "the frame visibly reads as three hands."
      ],
      "issueTags": [
        "background",
        "anatomy"
      ],
      "suggestedRoute": "redraw",
      "auditJsonPath": "audit-only/Bent_Over_One-Arm_Long_Bar_Row/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Bent_Over_One-Arm_Long_Bar_Row/Bent_Over_One-Arm_Long_Bar_Row_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Bent_Over_One-Arm_Long_Bar_Row/Bent_Over_One-Arm_Long_Bar_Row_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Bent_Over_One-Arm_Long_Bar_Row",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Bent_Over_One-Arm_Long_Bar_Row_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Bent_Over_One-Arm_Long_Bar_Row_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Bent_Over_One-Arm_Long_Bar_Row_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Bent_Over_One-Arm_Long_Bar_Row_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Bent_Over_One-Arm_Long_Bar_Row_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Bent_Over_One-Arm_Long_Bar_Row_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Bent_Over_One-Arm_Long_Bar_Row_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Bent_Over_One-Arm_Long_Bar_Row_female_v2_3.png"
      ]
    },
    {
      "index": 4,
      "exerciseId": "Bottoms_Up",
      "severity": "critical",
      "findings": [
        "Both frame 1 images introduce a barbell absent from the rest of the bodyweight sequence and rotate the camera/body orientation",
        "Opaque white enclosed background in male frame 1",
        "Frame 2 athlete scale increases substantially in both sequences",
        "Very tight side/bottom padding and pale ground patches across originals"
      ],
      "issueTags": [
        "background",
        "framing",
        "padding"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Bottoms_Up/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Bottoms_Up/Bottoms_Up_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Bottoms_Up/Bottoms_Up_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Bottoms_Up",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Bottoms_Up_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Bottoms_Up_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Bottoms_Up_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Bottoms_Up_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Bottoms_Up_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Bottoms_Up_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Bottoms_Up_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Bottoms_Up_female_v2_3.png"
      ]
    },
    {
      "index": 5,
      "exerciseId": "Brachialis-SMR",
      "severity": "critical",
      "findings": [
        "Opaque white enclosed gaps between the lower legs remain visible on dark backgrounds in every frame. Additional white wedges remain inside the bent-arm gap in male frames 0 and 3.",
        "The upper arm terminates at the top of the foam roller without a visible forearm or hand",
        "the sequence changes from a complete bent arm to an apparent stump. This is a substantially broken limb depiction.",
        "Thin pale contour fringe is visible against dark backgrounds, especially around clothing and hair",
        "female ponytail tips have conspicuous white edging."
      ],
      "issueTags": [
        "background",
        "anatomy"
      ],
      "suggestedRoute": "redraw",
      "auditJsonPath": "audit-only/Brachialis-SMR/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Brachialis-SMR/Brachialis-SMR_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Brachialis-SMR/Brachialis-SMR_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Brachialis-SMR",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Brachialis-SMR_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Brachialis-SMR_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Brachialis-SMR_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Brachialis-SMR_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Brachialis-SMR_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Brachialis-SMR_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Brachialis-SMR_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Brachialis-SMR_female_v2_3.png"
      ]
    },
    {
      "index": 6,
      "exerciseId": "Cable_Hip_Adduction",
      "severity": "critical",
      "findings": [
        "Cable runs from the low pulley to the standing leg's ankle instead of the cuff on the raised working leg. This visibly misrepresents the resistance attachment for hip adduction",
        "frame 2 switches to the crossing working ankle.",
        "Ragged, perforated cutout contours are visible on light backgrounds around clothing seams, shoes, machine rails and weight stack edges. Small transparent specks/notches interrupt dark outlines",
        "no broad opaque background or checkerboard interior is visible."
      ],
      "issueTags": [
        "background",
        "anatomy"
      ],
      "suggestedRoute": "redraw",
      "auditJsonPath": "audit-only/Cable_Hip_Adduction/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Cable_Hip_Adduction/Cable_Hip_Adduction_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Cable_Hip_Adduction/Cable_Hip_Adduction_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Cable_Hip_Adduction",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Cable_Hip_Adduction_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Cable_Hip_Adduction_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Cable_Hip_Adduction_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Cable_Hip_Adduction_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Cable_Hip_Adduction_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Cable_Hip_Adduction_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Cable_Hip_Adduction_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Cable_Hip_Adduction_female_v2_3.png"
      ]
    },
    {
      "index": 7,
      "exerciseId": "Cable_Wrist_Curl",
      "severity": "critical",
      "findings": [
        "Both sequences lift the forearms through substantial elbow flexion, culminating with the hands raised toward the chest in frame 3. The forearms do not remain supported on the thighs while the wrists move",
        "this depicts a seated cable arm curl rather than the assigned wrist curl.",
        "Solid white triangular background remains between the bench supports and in a lower cable-machine opening in all eight frames. Female frames also retain a conspicuous white gap between the torso and arm above the shorts. These remain white against the dark preview.",
        "Thin pale fringe and small white strips remain beneath bench feet and around portions of the equipment and shoes",
        "female hair also has pale edging visible on dark backgrounds."
      ],
      "issueTags": [
        "background"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Cable_Wrist_Curl/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Cable_Wrist_Curl/Cable_Wrist_Curl_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Cable_Wrist_Curl/Cable_Wrist_Curl_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Cable_Wrist_Curl",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Cable_Wrist_Curl_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Cable_Wrist_Curl_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Cable_Wrist_Curl_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Cable_Wrist_Curl_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Cable_Wrist_Curl_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Cable_Wrist_Curl_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Cable_Wrist_Curl_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Cable_Wrist_Curl_female_v2_3.png"
      ]
    },
    {
      "index": 8,
      "exerciseId": "Calf_Stretch_Elbows_Against_Wall",
      "severity": "critical",
      "findings": [
        "All frames show clasped hands raised overhead and a forward body lean, with no wall depicted and no elbows supported against a wall. The defining elbow-supported calf stretch is not demonstrated.",
        "An opaque white/light mottled patch remains in the enclosed gap between the head and raised arms in every frame. It remains white on the dark background and is clearly unwanted interior background."
      ],
      "issueTags": [
        "background",
        "anatomy"
      ],
      "suggestedRoute": "redraw",
      "auditJsonPath": "audit-only/Calf_Stretch_Elbows_Against_Wall/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Calf_Stretch_Elbows_Against_Wall/Calf_Stretch_Elbows_Against_Wall_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Calf_Stretch_Elbows_Against_Wall/Calf_Stretch_Elbows_Against_Wall_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Calf_Stretch_Elbows_Against_Wall",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Calf_Stretch_Elbows_Against_Wall_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Calf_Stretch_Elbows_Against_Wall_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Calf_Stretch_Elbows_Against_Wall_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Calf_Stretch_Elbows_Against_Wall_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Calf_Stretch_Elbows_Against_Wall_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Calf_Stretch_Elbows_Against_Wall_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Calf_Stretch_Elbows_Against_Wall_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Calf_Stretch_Elbows_Against_Wall_female_v2_3.png"
      ]
    },
    {
      "index": 9,
      "exerciseId": "Chest_Push_multiple_response",
      "severity": "critical",
      "findings": [
        "Frame 1 contains an extra detached half-ball at image-right while the athlete holds a complete ball. Frame 3 contains a detached shoe fragment at image-left, separate from the athlete. These are visibly broken multi-pose remnants.",
        "The released ball is truncated by a straight vertical cut inside the left canvas margin",
        "both feet/lower legs terminate at a straight vertical cut on the right. Transparent margins remain beyond these cuts, so the artwork itself is incomplete.",
        "Knee contact positions shift substantially rightward from setup through release and then leftward on return in both sequences. This moves the stationary kneeling base across the canvas, beyond the expected torso lean and arm/ball motion.",
        "Thin pale contour fringes and ragged light-gray ground patches are conspicuous against dark backgrounds. Ground shading may be intentional, but its pale hard edges and scattered gaps reduce cutout quality."
      ],
      "issueTags": [
        "background",
        "framing",
        "clipping",
        "anatomy"
      ],
      "suggestedRoute": "redraw",
      "auditJsonPath": "audit-only/Chest_Push_multiple_response/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Chest_Push_multiple_response/Chest_Push_multiple_response_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Chest_Push_multiple_response/Chest_Push_multiple_response_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Chest_Push_multiple_response",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Chest_Push_multiple_response_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Chest_Push_multiple_response_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Chest_Push_multiple_response_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Chest_Push_multiple_response_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Chest_Push_multiple_response_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Chest_Push_multiple_response_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Chest_Push_multiple_response_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Chest_Push_multiple_response_female_v2_3.png"
      ]
    },
    {
      "index": 10,
      "exerciseId": "Chest_Push_with_Run_Release",
      "severity": "critical",
      "findings": [
        "Released medicine ball is on image-right behind the athlete while both arms push toward image-left. This reverses the chest-pass trajectory and substantially misrepresents the release phase.",
        "Male frame 2 ball has a straight vertical cutoff on its right side within the canvas. Female frame 3 extended image-left fingertips terminate at an abrupt vertical cut within otherwise empty canvas.",
        "Pale gray/white patches beneath shoes and thin light contours around parts of the silhouettes remain conspicuous on dark backgrounds. Ground patches may be authored shadows, but appear as opaque pale islands."
      ],
      "issueTags": [
        "background",
        "anatomy"
      ],
      "suggestedRoute": "redraw",
      "auditJsonPath": "audit-only/Chest_Push_with_Run_Release/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Chest_Push_with_Run_Release/Chest_Push_with_Run_Release_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Chest_Push_with_Run_Release/Chest_Push_with_Run_Release_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Chest_Push_with_Run_Release",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Chest_Push_with_Run_Release_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Chest_Push_with_Run_Release_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Chest_Push_with_Run_Release_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Chest_Push_with_Run_Release_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Chest_Push_with_Run_Release_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Chest_Push_with_Run_Release_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Chest_Push_with_Run_Release_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Chest_Push_with_Run_Release_female_v2_3.png"
      ]
    },
    {
      "index": 11,
      "exerciseId": "Decline_Close-Grip_Bench_To_Skull_Crusher",
      "severity": "critical",
      "findings": [
        "Foreground upper arm ends at a rounded elbow beside the torso without a visible forearm connecting to the bar-gripping hand. The hand/wrist above the torso does not form a coherent connected arm.",
        "The barbell shaft runs diagonally between the plates, while the foreground hand grips a separate short shaft ending beside the face. This creates a forked/disconnected bar instead of a single coherent bar held by both hands.",
        "The stationary male bench and body shift modestly between frames: the head end and front base move horizontally and the support geometry changes slightly. This introduces limited anchor jitter beyond the intended arm/bar motion."
      ],
      "issueTags": [
        "framing",
        "anatomy"
      ],
      "suggestedRoute": "redraw",
      "auditJsonPath": "audit-only/Decline_Close-Grip_Bench_To_Skull_Crusher/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Decline_Close-Grip_Bench_To_Skull_Crusher/Decline_Close-Grip_Bench_To_Skull_Crusher_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Decline_Close-Grip_Bench_To_Skull_Crusher/Decline_Close-Grip_Bench_To_Skull_Crusher_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Decline_Close-Grip_Bench_To_Skull_Crusher",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Decline_Close-Grip_Bench_To_Skull_Crusher_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Decline_Close-Grip_Bench_To_Skull_Crusher_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Decline_Close-Grip_Bench_To_Skull_Crusher_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Decline_Close-Grip_Bench_To_Skull_Crusher_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Decline_Close-Grip_Bench_To_Skull_Crusher_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Decline_Close-Grip_Bench_To_Skull_Crusher_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Decline_Close-Grip_Bench_To_Skull_Crusher_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Decline_Close-Grip_Bench_To_Skull_Crusher_female_v2_3.png"
      ]
    },
    {
      "index": 12,
      "exerciseId": "Downward_Facing_Balance",
      "severity": "critical",
      "findings": [
        "Large opaque white/light checker-pattern areas remain beneath the athlete and around the ball. Frame 1 retains a broad rectangular background extending to the lower and right artwork boundaries.",
        "Extended hands terminate at the right artwork boundary in frame 1",
        "frame 2 cuts off the outstretched forearms and hands. This materially harms the full-pose depiction.",
        "A conspicuous detached forearm/hand fragment floats at the left edge above the athlete's legs in each frame 3, creating a multi-pose fragment image.",
        "Thin pale fringe follows many body/ball contours and white strips remain along parts of the mat edge. Frame 2 also has a small flesh-colored fragment at far left",
        "female frame 0 has a thin detached vertical mark at far right."
      ],
      "issueTags": [
        "background",
        "clipping"
      ],
      "suggestedRoute": "redraw",
      "auditJsonPath": "audit-only/Downward_Facing_Balance/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Downward_Facing_Balance/Downward_Facing_Balance_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Downward_Facing_Balance/Downward_Facing_Balance_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Downward_Facing_Balance",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Downward_Facing_Balance_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Downward_Facing_Balance_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Downward_Facing_Balance_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Downward_Facing_Balance_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Downward_Facing_Balance_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Downward_Facing_Balance_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Downward_Facing_Balance_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Downward_Facing_Balance_female_v2_3.png"
      ]
    },
    {
      "index": 13,
      "exerciseId": "Dumbbell_Lying_One-Arm_Rear_Lateral_Raise",
      "severity": "critical",
      "findings": [
        "At the peak female pose the near working shoulder terminates in a rounded stump inside the armhole",
        "the dumbbell-bearing arm emerges from behind the upper back on the far side rather than connecting to that shoulder. This breaks the working-arm anatomy and continuity from frames 0, 1 and 3.",
        "Thin pale fringe traces portions of the athlete and bench outlines on the dark background, including hair, limbs and interior bench openings. It is limited edge residue, not an opaque background."
      ],
      "issueTags": [
        "background",
        "anatomy"
      ],
      "suggestedRoute": "redraw",
      "auditJsonPath": "audit-only/Dumbbell_Lying_One-Arm_Rear_Lateral_Raise/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Dumbbell_Lying_One-Arm_Rear_Lateral_Raise/Dumbbell_Lying_One-Arm_Rear_Lateral_Raise_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Dumbbell_Lying_One-Arm_Rear_Lateral_Raise/Dumbbell_Lying_One-Arm_Rear_Lateral_Raise_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Dumbbell_Lying_One-Arm_Rear_Lateral_Raise",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dumbbell_Lying_One-Arm_Rear_Lateral_Raise_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dumbbell_Lying_One-Arm_Rear_Lateral_Raise_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dumbbell_Lying_One-Arm_Rear_Lateral_Raise_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dumbbell_Lying_One-Arm_Rear_Lateral_Raise_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dumbbell_Lying_One-Arm_Rear_Lateral_Raise_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dumbbell_Lying_One-Arm_Rear_Lateral_Raise_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dumbbell_Lying_One-Arm_Rear_Lateral_Raise_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dumbbell_Lying_One-Arm_Rear_Lateral_Raise_female_v2_3.png"
      ]
    },
    {
      "index": 14,
      "exerciseId": "Dumbbell_Lying_Supination",
      "severity": "critical",
      "findings": [
        "Raised dumbbell has an upper weight plate but no lower weight plate: the handle ends below the fist as a bare short shaft. Other frames and female frame 2 show a two-ended dumbbell, so equipment visibly changes into a one-ended object.",
        "Small opaque white crescent remains in the bench opening beneath the dumbbell in male frame 0 and female frame 0. All female frames also retain a small white triangular sliver between the supporting upper arm/torso and bench, visible against the dark background.",
        "Bench top and feet shift slightly downward between early and late frames, more visibly in the female sequence. This is limited stationary-equipment drift, separate from the intended arm movement."
      ],
      "issueTags": [
        "background",
        "framing"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Dumbbell_Lying_Supination/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Dumbbell_Lying_Supination/Dumbbell_Lying_Supination_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Dumbbell_Lying_Supination/Dumbbell_Lying_Supination_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Dumbbell_Lying_Supination",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dumbbell_Lying_Supination_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dumbbell_Lying_Supination_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dumbbell_Lying_Supination_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dumbbell_Lying_Supination_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dumbbell_Lying_Supination_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dumbbell_Lying_Supination_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dumbbell_Lying_Supination_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dumbbell_Lying_Supination_female_v2_3.png"
      ]
    },
    {
      "index": 15,
      "exerciseId": "Dumbbell_Tricep_Extension_-Pronated_Grip",
      "severity": "critical",
      "findings": [
        "Frame 2 in both variants depicts the torso ending beneath folded arms/dumbbells with no recognizable head",
        "the female ponytail also disappears. Compared with adjacent frames this reads as missing head anatomy rather than a usable lowering phase.",
        "Detached shoe/toe artwork floats at the right side, separate from the athlete and bench. Male frame 1 has a smaller fragment",
        "both frame-2 fragments are conspicuous.",
        "The image-left shoe ends at an abrupt vertical cut within the transparent canvas, removing part of its toe. Particularly obvious in both frame-3 images.",
        "Stationary bench and feet shift laterally between frames, especially into frame 3. This produces a modest animation jump beyond the intended arm movement."
      ],
      "issueTags": [
        "background",
        "framing",
        "clipping",
        "anatomy"
      ],
      "suggestedRoute": "redraw",
      "auditJsonPath": "audit-only/Dumbbell_Tricep_Extension_-Pronated_Grip/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Dumbbell_Tricep_Extension_-Pronated_Grip/Dumbbell_Tricep_Extension_-Pronated_Grip_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Dumbbell_Tricep_Extension_-Pronated_Grip/Dumbbell_Tricep_Extension_-Pronated_Grip_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Dumbbell_Tricep_Extension_-Pronated_Grip",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dumbbell_Tricep_Extension_-Pronated_Grip_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dumbbell_Tricep_Extension_-Pronated_Grip_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dumbbell_Tricep_Extension_-Pronated_Grip_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dumbbell_Tricep_Extension_-Pronated_Grip_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dumbbell_Tricep_Extension_-Pronated_Grip_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dumbbell_Tricep_Extension_-Pronated_Grip_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dumbbell_Tricep_Extension_-Pronated_Grip_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dumbbell_Tricep_Extension_-Pronated_Grip_female_v2_3.png"
      ]
    },
    {
      "index": 16,
      "exerciseId": "Dynamic_Back_Stretch",
      "severity": "critical",
      "findings": [
        "Each overhead pose includes a separate, disconnected forearm and hand floating to the right of the athlete, with a straight cut end. This is an extra limb fragment from another pose.",
        "The arm extending toward image-left stops at a straight vertical cut through the forearm",
        "the remaining forearm and hand are absent despite ample transparent canvas. The exercise pose is substantially broken.",
        "The standing body and planted feet shift markedly left in frame 2 and back right in frame 3 relative to frames 0 and 1, producing a lateral jump unrelated to the arm raise. Identity and drawing style otherwise remain consistent."
      ],
      "issueTags": [
        "background",
        "framing",
        "clipping",
        "anatomy"
      ],
      "suggestedRoute": "redraw",
      "auditJsonPath": "audit-only/Dynamic_Back_Stretch/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Dynamic_Back_Stretch/Dynamic_Back_Stretch_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Dynamic_Back_Stretch/Dynamic_Back_Stretch_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Dynamic_Back_Stretch",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dynamic_Back_Stretch_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dynamic_Back_Stretch_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dynamic_Back_Stretch_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dynamic_Back_Stretch_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dynamic_Back_Stretch_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dynamic_Back_Stretch_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dynamic_Back_Stretch_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Dynamic_Back_Stretch_female_v2_3.png"
      ]
    },
    {
      "index": 17,
      "exerciseId": "EZ-Bar_Skullcrusher",
      "severity": "critical",
      "findings": [
        "Right weight plate and bar end are cut off at a hard vertical boundary.",
        "Detached weight plate at upper left and detached shoe fragments at lower right",
        "main right plate is also cut off.",
        "Detached weight plate at upper left and detached shoe fragments at lower right",
        "main shoes are cut off at left.",
        "Both shoes are cut off at a hard left boundary.",
        "Right weight plate/bar end and rear hair are cut off at a hard vertical boundary.",
        "Detached weight plate and ponytail fragments at left, plus small right-edge fragment",
        "main right plate is cut off.",
        "Detached weight plate at upper left and shoes at lower right",
        "main left shoe is cut off.",
        "Both shoes are cut off at a hard left boundary.",
        "Stationary bench, torso and feet shift horizontally across the ordered frames in both variants",
        "hard cut boundaries and detached fragments appear/disappear. This is separate from the intended elbow motion and materially disrupts the animation."
      ],
      "issueTags": [
        "framing",
        "clipping"
      ],
      "suggestedRoute": "redraw",
      "auditJsonPath": "audit-only/EZ-Bar_Skullcrusher/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/EZ-Bar_Skullcrusher/EZ-Bar_Skullcrusher_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/EZ-Bar_Skullcrusher/EZ-Bar_Skullcrusher_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/EZ-Bar_Skullcrusher",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/EZ-Bar_Skullcrusher_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/EZ-Bar_Skullcrusher_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/EZ-Bar_Skullcrusher_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/EZ-Bar_Skullcrusher_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/EZ-Bar_Skullcrusher_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/EZ-Bar_Skullcrusher_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/EZ-Bar_Skullcrusher_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/EZ-Bar_Skullcrusher_female_v2_3.png"
      ]
    },
    {
      "index": 18,
      "exerciseId": "Front_Barbell_Squat_To_A_Bench",
      "severity": "critical",
      "findings": [
        "All male frames show the bar visibly crossing the rear upper shoulders/back with a back-squat grip rather than a front rack. Female frame 3 also draws the shaft continuously across the rear shoulders/upper arm. This materially misdepicts the named front barbell squat to a bench.",
        "Fine green speckled fringe is visible along portions of athlete, plates and bench outlines against the dark background. It is limited to thin edges",
        "no large opaque background or checkerboard interiors were observed.",
        "Stationary bench geometry and position vary between phases, with foot anchors drifting as well. Male frame 2 enlarges the bar/plates relative to adjacent phases",
        "female frame 3 widens the bar and bench compared with frame 0. These introduce visible but limited animation discontinuities beyond expected squat motion."
      ],
      "issueTags": [
        "background",
        "framing",
        "anatomy"
      ],
      "suggestedRoute": "redraw",
      "auditJsonPath": "audit-only/Front_Barbell_Squat_To_A_Bench/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Front_Barbell_Squat_To_A_Bench/Front_Barbell_Squat_To_A_Bench_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Front_Barbell_Squat_To_A_Bench/Front_Barbell_Squat_To_A_Bench_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Front_Barbell_Squat_To_A_Bench",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Front_Barbell_Squat_To_A_Bench_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Front_Barbell_Squat_To_A_Bench_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Front_Barbell_Squat_To_A_Bench_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Front_Barbell_Squat_To_A_Bench_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Front_Barbell_Squat_To_A_Bench_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Front_Barbell_Squat_To_A_Bench_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Front_Barbell_Squat_To_A_Bench_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Front_Barbell_Squat_To_A_Bench_female_v2_3.png"
      ]
    },
    {
      "index": 19,
      "exerciseId": "Kettlebell_Turkish_Get-Up_Lunge_style",
      "severity": "critical",
      "findings": [
        "All eight originals contain opaque white/gray background remnants, including enclosed limb gaps",
        "Male frame 1 has a clipped supporting arm and detached hand fragment",
        "Male frame 2 contains an unrelated detached arm at the left",
        "Female sequence does not reach the lunge or standing phase and returns to its initial floor pose",
        "Male scale and framing vary with very tight top padding in standing frame"
      ],
      "issueTags": [
        "background",
        "framing",
        "clipping",
        "padding"
      ],
      "suggestedRoute": "redraw",
      "auditJsonPath": "audit-only/Kettlebell_Turkish_Get-Up_Lunge_style/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Kettlebell_Turkish_Get-Up_Lunge_style/Kettlebell_Turkish_Get-Up_Lunge_style_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Kettlebell_Turkish_Get-Up_Lunge_style/Kettlebell_Turkish_Get-Up_Lunge_style_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Kettlebell_Turkish_Get-Up_Lunge_style",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Kettlebell_Turkish_Get-Up_Lunge_style_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Kettlebell_Turkish_Get-Up_Lunge_style_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Kettlebell_Turkish_Get-Up_Lunge_style_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Kettlebell_Turkish_Get-Up_Lunge_style_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Kettlebell_Turkish_Get-Up_Lunge_style_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Kettlebell_Turkish_Get-Up_Lunge_style_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Kettlebell_Turkish_Get-Up_Lunge_style_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Kettlebell_Turkish_Get-Up_Lunge_style_female_v2_3.png"
      ]
    },
    {
      "index": 20,
      "exerciseId": "Kettlebell_Turkish_Get-Up_Squat_style",
      "severity": "critical",
      "findings": [
        "Clipped body parts in setup/seated frames",
        "Detached adjacent-pose limbs in transition frames",
        "White/checkerboard backgrounds and ground shadows",
        "Female original frame 2 uses half-kneeling instead of squat-style transition"
      ],
      "issueTags": [
        "background",
        "clipping"
      ],
      "suggestedRoute": "redraw",
      "auditJsonPath": "audit-only/Kettlebell_Turkish_Get-Up_Squat_style/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Kettlebell_Turkish_Get-Up_Squat_style/Kettlebell_Turkish_Get-Up_Squat_style_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Kettlebell_Turkish_Get-Up_Squat_style/Kettlebell_Turkish_Get-Up_Squat_style_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Kettlebell_Turkish_Get-Up_Squat_style",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Kettlebell_Turkish_Get-Up_Squat_style_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Kettlebell_Turkish_Get-Up_Squat_style_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Kettlebell_Turkish_Get-Up_Squat_style_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Kettlebell_Turkish_Get-Up_Squat_style_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Kettlebell_Turkish_Get-Up_Squat_style_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Kettlebell_Turkish_Get-Up_Squat_style_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Kettlebell_Turkish_Get-Up_Squat_style_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Kettlebell_Turkish_Get-Up_Squat_style_female_v2_3.png"
      ]
    },
    {
      "index": 21,
      "exerciseId": "3_4_Sit-Up",
      "severity": "major",
      "findings": [
        "Opaque white enclosed arm/neck gaps in female frames 1-3",
        "Horizontal planted-foot drift across both sequences",
        "Tight bottom padding"
      ],
      "issueTags": [
        "background",
        "framing",
        "padding"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/3_4_Sit-Up/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/3_4_Sit-Up/3_4_Sit-Up_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/3_4_Sit-Up/3_4_Sit-Up_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/3_4_Sit-Up",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/3_4_Sit-Up_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/3_4_Sit-Up_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/3_4_Sit-Up_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/3_4_Sit-Up_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/3_4_Sit-Up_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/3_4_Sit-Up_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/3_4_Sit-Up_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/3_4_Sit-Up_female_v2_3.png"
      ]
    },
    {
      "index": 22,
      "exerciseId": "Ab_Crunch_Machine",
      "severity": "major",
      "findings": [
        "Thin vertical guide rods/cables are visibly fragmented in weight tower in all eight frames, especially on light background.",
        "Stray yellow-green opaque patch between shoes in male frame 0, with smaller remnants in male frame 1.",
        "Stationary machine tower/base shifts horizontally and changes apparent scale across both sequences",
        "cannot correct all anchors using a simple global translation without affecting athlete motion."
      ],
      "issueTags": [
        "background",
        "framing",
        "clipping"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Ab_Crunch_Machine/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Ab_Crunch_Machine/Ab_Crunch_Machine_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Ab_Crunch_Machine/Ab_Crunch_Machine_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Ab_Crunch_Machine",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ab_Crunch_Machine_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ab_Crunch_Machine_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ab_Crunch_Machine_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ab_Crunch_Machine_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ab_Crunch_Machine_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ab_Crunch_Machine_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ab_Crunch_Machine_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ab_Crunch_Machine_female_v2_3.png"
      ]
    },
    {
      "index": 23,
      "exerciseId": "Ab_Roller",
      "severity": "major",
      "findings": [
        "Pale perimeter and mat residue",
        "White background gaps beneath calves",
        "Artwork placed at bottom canvas boundary"
      ],
      "issueTags": [
        "background",
        "padding"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Ab_Roller/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Ab_Roller/Ab_Roller_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Ab_Roller/Ab_Roller_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Ab_Roller",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ab_Roller_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ab_Roller_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ab_Roller_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ab_Roller_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ab_Roller_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ab_Roller_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ab_Roller_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ab_Roller_female_v2_3.png"
      ]
    },
    {
      "index": 24,
      "exerciseId": "Adductor_Groin",
      "severity": "major",
      "findings": [
        "White outline residue around figures and gray-white ground patches under supine figures across both sequences",
        "Black rectangular residue below standing shoes in several frames",
        "Original bottom padding is small, approximately 12 pixels"
      ],
      "issueTags": [
        "background",
        "framing",
        "padding"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Adductor_Groin/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Adductor_Groin/Adductor_Groin_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Adductor_Groin/Adductor_Groin_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Adductor_Groin",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Adductor_Groin_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Adductor_Groin_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Adductor_Groin_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Adductor_Groin_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Adductor_Groin_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Adductor_Groin_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Adductor_Groin_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Adductor_Groin_female_v2_3.png"
      ]
    },
    {
      "index": 25,
      "exerciseId": "Alternate_Heel_Touchers",
      "severity": "major",
      "findings": [
        "Enclosed white background in action frames",
        "Dark rectangular shoe-background residue"
      ],
      "issueTags": [
        "background"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Alternate_Heel_Touchers/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Alternate_Heel_Touchers/Alternate_Heel_Touchers_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Alternate_Heel_Touchers/Alternate_Heel_Touchers_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Alternate_Heel_Touchers",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternate_Heel_Touchers_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternate_Heel_Touchers_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternate_Heel_Touchers_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternate_Heel_Touchers_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternate_Heel_Touchers_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternate_Heel_Touchers_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternate_Heel_Touchers_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternate_Heel_Touchers_female_v2_3.png"
      ]
    },
    {
      "index": 26,
      "exerciseId": "Alternating_Deltoid_Raise",
      "severity": "major",
      "findings": [
        "Male and female frame 3 image-left dumbbell outer plate is sharply truncated inside the canvas",
        "Light edge residue visible against dark backgrounds, especially in arm-to-torso gaps of neutral frames"
      ],
      "issueTags": [
        "background",
        "clipping"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Alternating_Deltoid_Raise/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Alternating_Deltoid_Raise/Alternating_Deltoid_Raise_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Alternating_Deltoid_Raise/Alternating_Deltoid_Raise_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Alternating_Deltoid_Raise",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Deltoid_Raise_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Deltoid_Raise_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Deltoid_Raise_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Deltoid_Raise_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Deltoid_Raise_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Deltoid_Raise_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Deltoid_Raise_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Deltoid_Raise_female_v2_3.png"
      ]
    },
    {
      "index": 27,
      "exerciseId": "Alternating_Floor_Press",
      "severity": "major",
      "findings": [
        "Male frame 2 had malformed dumbbell end weights and ragged arm contours"
      ],
      "issueTags": [
        "other"
      ],
      "suggestedRoute": "defer",
      "auditJsonPath": "audit-only/Alternating_Floor_Press/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Alternating_Floor_Press/Alternating_Floor_Press_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Alternating_Floor_Press/Alternating_Floor_Press_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Alternating_Floor_Press",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Floor_Press_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Floor_Press_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Floor_Press_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Floor_Press_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Floor_Press_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Floor_Press_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Floor_Press_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Floor_Press_female_v2_3.png"
      ]
    },
    {
      "index": 28,
      "exerciseId": "Alternating_Hang_Clean",
      "severity": "major",
      "findings": [
        "Opaque white/checkered background in lowered arm/torso gaps and kettlebell handle holes across all eight frames."
      ],
      "issueTags": [
        "background"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Alternating_Hang_Clean/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Alternating_Hang_Clean/Alternating_Hang_Clean_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Alternating_Hang_Clean/Alternating_Hang_Clean_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Alternating_Hang_Clean",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Hang_Clean_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Hang_Clean_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Hang_Clean_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Hang_Clean_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Hang_Clean_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Hang_Clean_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Hang_Clean_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Hang_Clean_female_v2_3.png"
      ]
    },
    {
      "index": 29,
      "exerciseId": "Alternating_Kettlebell_Press",
      "severity": "major",
      "findings": [
        "Resting frames 0 and 3 had larger character scale than overhead frames in both gender sequences."
      ],
      "issueTags": [
        "framing"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Alternating_Kettlebell_Press/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Alternating_Kettlebell_Press/Alternating_Kettlebell_Press_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Alternating_Kettlebell_Press/Alternating_Kettlebell_Press_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Alternating_Kettlebell_Press",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Kettlebell_Press_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Kettlebell_Press_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Kettlebell_Press_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Kettlebell_Press_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Kettlebell_Press_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Kettlebell_Press_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Kettlebell_Press_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Alternating_Kettlebell_Press_female_v2_3.png"
      ]
    },
    {
      "index": 30,
      "exerciseId": "Ankle_Circles",
      "severity": "major",
      "findings": [
        "White background in image-left arm/torso gap of all four female frames",
        "White background in image-right arm/torso gap of female frame 0"
      ],
      "issueTags": [
        "background"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Ankle_Circles/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Ankle_Circles/Ankle_Circles_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Ankle_Circles/Ankle_Circles_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Ankle_Circles",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ankle_Circles_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ankle_Circles_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ankle_Circles_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ankle_Circles_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ankle_Circles_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ankle_Circles_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ankle_Circles_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ankle_Circles_female_v2_3.png"
      ]
    },
    {
      "index": 31,
      "exerciseId": "Ankle_On_The_Knee",
      "severity": "major",
      "findings": [
        "Enclosed white/checkerboard leg gaps in female frames 0, 1, 2 and male frames 1, 2"
      ],
      "issueTags": [
        "background"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Ankle_On_The_Knee/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Ankle_On_The_Knee/Ankle_On_The_Knee_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Ankle_On_The_Knee/Ankle_On_The_Knee_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Ankle_On_The_Knee",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ankle_On_The_Knee_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ankle_On_The_Knee_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ankle_On_The_Knee_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ankle_On_The_Knee_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ankle_On_The_Knee_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ankle_On_The_Knee_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ankle_On_The_Knee_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ankle_On_The_Knee_female_v2_3.png"
      ]
    },
    {
      "index": 32,
      "exerciseId": "Anti-Gravity_Press",
      "severity": "major",
      "findings": [
        "Opaque background enclosed by bench in all frames",
        "Opaque gaps near arms and legs",
        "Horizontal sequence framing shifts",
        "Tiny detached background marks"
      ],
      "issueTags": [
        "background",
        "framing",
        "clipping"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Anti-Gravity_Press/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Anti-Gravity_Press/Anti-Gravity_Press_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Anti-Gravity_Press/Anti-Gravity_Press_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Anti-Gravity_Press",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Anti-Gravity_Press_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Anti-Gravity_Press_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Anti-Gravity_Press_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Anti-Gravity_Press_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Anti-Gravity_Press_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Anti-Gravity_Press_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Anti-Gravity_Press_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Anti-Gravity_Press_female_v2_3.png"
      ]
    },
    {
      "index": 33,
      "exerciseId": "Arnold_Dumbbell_Press",
      "severity": "major",
      "findings": [
        "Opaque white enclosed background between image-left forearm and torso in male frames 0 and 3"
      ],
      "issueTags": [
        "background"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Arnold_Dumbbell_Press/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Arnold_Dumbbell_Press/Arnold_Dumbbell_Press_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Arnold_Dumbbell_Press/Arnold_Dumbbell_Press_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Arnold_Dumbbell_Press",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Arnold_Dumbbell_Press_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Arnold_Dumbbell_Press_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Arnold_Dumbbell_Press_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Arnold_Dumbbell_Press_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Arnold_Dumbbell_Press_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Arnold_Dumbbell_Press_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Arnold_Dumbbell_Press_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Arnold_Dumbbell_Press_female_v2_3.png"
      ]
    },
    {
      "index": 34,
      "exerciseId": "Around_The_Worlds",
      "severity": "major",
      "findings": [
        "Opaque white enclosed background under male heads and female heads/ponytails",
        "male frame 1 also retains white between arm and torso",
        "Male frame 0 is smaller than adjacent frames",
        "bench position, tilt and scale vary through both sequences",
        "Joined-hand/single-dumbbell poses, particularly overhead and bent-elbow return frames, do not establish a consistent two-dumbbell Around The Worlds sweep"
      ],
      "issueTags": [
        "background",
        "framing"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Around_The_Worlds/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Around_The_Worlds/Around_The_Worlds_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Around_The_Worlds/Around_The_Worlds_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Around_The_Worlds",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Around_The_Worlds_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Around_The_Worlds_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Around_The_Worlds_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Around_The_Worlds_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Around_The_Worlds_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Around_The_Worlds_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Around_The_Worlds_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Around_The_Worlds_female_v2_3.png"
      ]
    },
    {
      "index": 35,
      "exerciseId": "Atlas_Stone_Trainer",
      "severity": "major",
      "findings": [
        "Original independent height normalization made athlete and equipment shrink from bent setup to upright lift, with shifting planted foot."
      ],
      "issueTags": [
        "framing"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Atlas_Stone_Trainer/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Atlas_Stone_Trainer/Atlas_Stone_Trainer_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Atlas_Stone_Trainer/Atlas_Stone_Trainer_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Atlas_Stone_Trainer",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Atlas_Stone_Trainer_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Atlas_Stone_Trainer_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Atlas_Stone_Trainer_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Atlas_Stone_Trainer_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Atlas_Stone_Trainer_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Atlas_Stone_Trainer_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Atlas_Stone_Trainer_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Atlas_Stone_Trainer_female_v2_3.png"
      ]
    },
    {
      "index": 36,
      "exerciseId": "Atlas_Stones",
      "severity": "major",
      "findings": [
        "Trapped white/checkerboard background beside stone and shoes in both frame 0 images",
        "Pose-dependent source enlargement caused shrinking stone and character scale changes through lift"
      ],
      "issueTags": [
        "background",
        "framing"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Atlas_Stones/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Atlas_Stones/Atlas_Stones_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Atlas_Stones/Atlas_Stones_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Atlas_Stones",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Atlas_Stones_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Atlas_Stones_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Atlas_Stones_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Atlas_Stones_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Atlas_Stones_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Atlas_Stones_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Atlas_Stones_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Atlas_Stones_female_v2_3.png"
      ]
    },
    {
      "index": 37,
      "exerciseId": "Back_Flyes_-_With_Bands",
      "severity": "major",
      "findings": [
        "Broken or missing resistance-band pixels across all eight frames, most severe in female frames 2 and 3 and male frames 1 and 3.",
        "Fragmented pale shoe soles across the sequence indicate foreground cutout loss.",
        "Male frame 3 has an opaque white enclosed background triangle under image-right arm.",
        "Female frame 2 band routing differs from adjacent frames",
        "reconstruction requires artwork judgment."
      ],
      "issueTags": [
        "background",
        "clipping",
        "anatomy"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Back_Flyes_-_With_Bands/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Back_Flyes_-_With_Bands/Back_Flyes_-_With_Bands_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Back_Flyes_-_With_Bands/Back_Flyes_-_With_Bands_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Back_Flyes_-_With_Bands",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Back_Flyes_-_With_Bands_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Back_Flyes_-_With_Bands_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Back_Flyes_-_With_Bands_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Back_Flyes_-_With_Bands_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Back_Flyes_-_With_Bands_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Back_Flyes_-_With_Bands_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Back_Flyes_-_With_Bands_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Back_Flyes_-_With_Bands_female_v2_3.png"
      ]
    },
    {
      "index": 38,
      "exerciseId": "Backward_Drag",
      "severity": "major",
      "findings": [
        "Opaque white backgrounds in female handle openings (frames 0, 1, 2)",
        "White/gray background remnants beneath male sleds and raised feet",
        "Pre-existing erased front-handle material in female frames 1 and 3"
      ],
      "issueTags": [
        "background"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Backward_Drag/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Backward_Drag/Backward_Drag_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Backward_Drag/Backward_Drag_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Backward_Drag",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Backward_Drag_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Backward_Drag_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Backward_Drag_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Backward_Drag_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Backward_Drag_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Backward_Drag_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Backward_Drag_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Backward_Drag_female_v2_3.png"
      ]
    },
    {
      "index": 39,
      "exerciseId": "Backward_Medicine_Ball_Throw",
      "severity": "major",
      "findings": [
        "Opaque white enclosed backgrounds between raised arms in male/female frame 2",
        "Opaque white gaps beside ball and arms in male/female frame 1",
        "Small white background remnants beside female hair",
        "Character and ball scale changed substantially across original frames, most prominently overhead frames"
      ],
      "issueTags": [
        "background",
        "framing"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Backward_Medicine_Ball_Throw/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Backward_Medicine_Ball_Throw/Backward_Medicine_Ball_Throw_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Backward_Medicine_Ball_Throw/Backward_Medicine_Ball_Throw_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Backward_Medicine_Ball_Throw",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Backward_Medicine_Ball_Throw_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Backward_Medicine_Ball_Throw_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Backward_Medicine_Ball_Throw_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Backward_Medicine_Ball_Throw_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Backward_Medicine_Ball_Throw_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Backward_Medicine_Ball_Throw_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Backward_Medicine_Ball_Throw_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Backward_Medicine_Ball_Throw_female_v2_3.png"
      ]
    },
    {
      "index": 40,
      "exerciseId": "Ball_Leg_Curl",
      "severity": "major",
      "findings": [
        "Ball diameter varies visibly across both sequences, especially frame 2 versus frame 3",
        "Frame 2 enlarges the athlete and shifts resting head/shoulder position",
        "Very tight original side and bottom padding"
      ],
      "issueTags": [
        "framing",
        "padding"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Ball_Leg_Curl/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Ball_Leg_Curl/Ball_Leg_Curl_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Ball_Leg_Curl/Ball_Leg_Curl_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Ball_Leg_Curl",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ball_Leg_Curl_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ball_Leg_Curl_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ball_Leg_Curl_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ball_Leg_Curl_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ball_Leg_Curl_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ball_Leg_Curl_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ball_Leg_Curl_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Ball_Leg_Curl_female_v2_3.png"
      ]
    },
    {
      "index": 41,
      "exerciseId": "Band_Assisted_Pull-Up",
      "severity": "major",
      "findings": [
        "Original bar width varies across frames (male 496\u2013559 px",
        "female 498\u2013557 px)",
        "Stationary bar shifts vertically, particularly male peak frame",
        "original feet are bottom-normalized instead of preserving pull-up displacement",
        "Original artwork has only about 12 pixels of outer padding"
      ],
      "issueTags": [
        "framing"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Band_Assisted_Pull-Up/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Band_Assisted_Pull-Up/Band_Assisted_Pull-Up_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Band_Assisted_Pull-Up/Band_Assisted_Pull-Up_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Band_Assisted_Pull-Up",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Assisted_Pull-Up_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Assisted_Pull-Up_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Assisted_Pull-Up_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Assisted_Pull-Up_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Assisted_Pull-Up_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Assisted_Pull-Up_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Assisted_Pull-Up_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Assisted_Pull-Up_female_v2_3.png"
      ]
    },
    {
      "index": 42,
      "exerciseId": "Band_Good_Morning",
      "severity": "major",
      "findings": [
        "Original frames fitted standing and hinged poses to the same 722-pixel height, causing character enlargement through the hinge.",
        "Original feet had only 12 pixels of bottom padding and shifted horizontally."
      ],
      "issueTags": [
        "framing",
        "padding"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Band_Good_Morning/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Band_Good_Morning/Band_Good_Morning_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Band_Good_Morning/Band_Good_Morning_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Band_Good_Morning",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Good_Morning_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Good_Morning_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Good_Morning_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Good_Morning_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Good_Morning_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Good_Morning_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Good_Morning_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Good_Morning_female_v2_3.png"
      ]
    },
    {
      "index": 43,
      "exerciseId": "Band_Good_Morning_Pull_Through",
      "severity": "major",
      "findings": [
        "Opaque white enclosed shoulder gaps in all eight frames",
        "Opaque white enclosed female anchor holes"
      ],
      "issueTags": [
        "background",
        "framing"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Band_Good_Morning_Pull_Through/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Band_Good_Morning_Pull_Through/Band_Good_Morning_Pull_Through_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Band_Good_Morning_Pull_Through/Band_Good_Morning_Pull_Through_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Band_Good_Morning_Pull_Through",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Good_Morning_Pull_Through_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Good_Morning_Pull_Through_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Good_Morning_Pull_Through_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Good_Morning_Pull_Through_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Good_Morning_Pull_Through_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Good_Morning_Pull_Through_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Good_Morning_Pull_Through_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Good_Morning_Pull_Through_female_v2_3.png"
      ]
    },
    {
      "index": 44,
      "exerciseId": "Band_Hip_Adductions",
      "severity": "major",
      "findings": [
        "Wall mount position drift between frames, most pronounced in frame 2 of both genders"
      ],
      "issueTags": [
        "framing"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Band_Hip_Adductions/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Band_Hip_Adductions/Band_Hip_Adductions_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Band_Hip_Adductions/Band_Hip_Adductions_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Band_Hip_Adductions",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Hip_Adductions_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Hip_Adductions_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Hip_Adductions_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Hip_Adductions_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Hip_Adductions_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Hip_Adductions_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Hip_Adductions_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Band_Hip_Adductions_female_v2_3.png"
      ]
    },
    {
      "index": 45,
      "exerciseId": "Barbell_Ab_Rollout",
      "severity": "major",
      "findings": [
        "Opaque white/checkerboard enclosed limb gaps in all eight originals",
        "Inconsistent character scale and foot placement across original sequence",
        "White background remnants beneath male frame 3 plates"
      ],
      "issueTags": [
        "background",
        "framing"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Barbell_Ab_Rollout/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Barbell_Ab_Rollout/Barbell_Ab_Rollout_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Barbell_Ab_Rollout/Barbell_Ab_Rollout_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Barbell_Ab_Rollout",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Ab_Rollout_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Ab_Rollout_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Ab_Rollout_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Ab_Rollout_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Ab_Rollout_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Ab_Rollout_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Ab_Rollout_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Ab_Rollout_female_v2_3.png"
      ]
    },
    {
      "index": 46,
      "exerciseId": "Barbell_Bench_Press_-_Medium_Grip",
      "severity": "major",
      "findings": [
        "White floor/background remnants in all eight frames, especially female sets",
        "Stray equipment fragments in male 1/2/3 and female 1/2",
        "Clipped equipment in male 0/1 and female 0",
        "left shoe edge male 3",
        "Sequence framing and stationary rack anchors shift"
      ],
      "issueTags": [
        "background",
        "framing",
        "clipping"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Barbell_Bench_Press_-_Medium_Grip/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Barbell_Bench_Press_-_Medium_Grip/Barbell_Bench_Press_-_Medium_Grip_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Barbell_Bench_Press_-_Medium_Grip/Barbell_Bench_Press_-_Medium_Grip_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Barbell_Bench_Press_-_Medium_Grip",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Bench_Press_-_Medium_Grip_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Bench_Press_-_Medium_Grip_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Bench_Press_-_Medium_Grip_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Bench_Press_-_Medium_Grip_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Bench_Press_-_Medium_Grip_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Bench_Press_-_Medium_Grip_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Bench_Press_-_Medium_Grip_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Bench_Press_-_Medium_Grip_female_v2_3.png"
      ]
    },
    {
      "index": 47,
      "exerciseId": "Barbell_Curl",
      "severity": "major",
      "findings": [
        "White ground patches beneath shoes in all eight originals",
        "Detached equipment remnants in male frames 1, 2, 3 and female frames 0, 3"
      ],
      "issueTags": [
        "background",
        "clipping"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Barbell_Curl/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Barbell_Curl/Barbell_Curl_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Barbell_Curl/Barbell_Curl_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Barbell_Curl",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Curl_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Curl_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Curl_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Curl_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Curl_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Curl_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Curl_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Curl_female_v2_3.png"
      ]
    },
    {
      "index": 48,
      "exerciseId": "Barbell_Curls_Lying_Against_An_Incline",
      "severity": "major",
      "findings": [
        "White ground remnants in all eight frames",
        "Abruptly clipped right barbell plates in male 0/1 and female 0/1/2",
        "Detached plate fragments at left in male 1/2 and female 1/2/3",
        "Small detached artifacts at right in male 2"
      ],
      "issueTags": [
        "background",
        "clipping"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Barbell_Curls_Lying_Against_An_Incline/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Barbell_Curls_Lying_Against_An_Incline/Barbell_Curls_Lying_Against_An_Incline_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Barbell_Curls_Lying_Against_An_Incline/Barbell_Curls_Lying_Against_An_Incline_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Barbell_Curls_Lying_Against_An_Incline",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Curls_Lying_Against_An_Incline_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Curls_Lying_Against_An_Incline_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Curls_Lying_Against_An_Incline_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Curls_Lying_Against_An_Incline_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Curls_Lying_Against_An_Incline_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Curls_Lying_Against_An_Incline_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Curls_Lying_Against_An_Incline_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Curls_Lying_Against_An_Incline_female_v2_3.png"
      ]
    },
    {
      "index": 49,
      "exerciseId": "Barbell_Deadlift",
      "severity": "major",
      "findings": [
        "White floor residue in all eight originals",
        "Stray disconnected barbell fragments in male 1 and female 1, 2, 3",
        "Abrupt equipment cutoffs in male 0, male 2 and female 1, 2",
        "Frame-to-frame framing and equipment inconsistencies"
      ],
      "issueTags": [
        "background",
        "framing",
        "clipping",
        "anatomy"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Barbell_Deadlift/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Barbell_Deadlift/Barbell_Deadlift_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Barbell_Deadlift/Barbell_Deadlift_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Barbell_Deadlift",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Deadlift_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Deadlift_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Deadlift_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Deadlift_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Deadlift_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Deadlift_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Deadlift_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Deadlift_female_v2_3.png"
      ]
    },
    {
      "index": 50,
      "exerciseId": "Barbell_Guillotine_Bench_Press",
      "severity": "major",
      "findings": [
        "Opaque white/gray floor and shadow patches beneath bench in all frames, including enclosed holes",
        "Transparent speckle damage on pale rack uprights",
        "Detached equipment fragments in male 1 and female 1, stray marks in female 2",
        "Rack geometry and stationary anchors change across sequence",
        "female frame 0 right rack is abruptly cut off"
      ],
      "issueTags": [
        "background",
        "framing",
        "clipping"
      ],
      "suggestedRoute": "script_fix",
      "auditJsonPath": "audit-only/Barbell_Guillotine_Bench_Press/result.json",
      "maleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Barbell_Guillotine_Bench_Press/Barbell_Guillotine_Bench_Press_male-contact.png",
      "femaleContact": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Barbell_Guillotine_Bench_Press/Barbell_Guillotine_Bench_Press_female-contact.png",
      "previewDir": "/Users/apoorvdarshan/fud-ai/artifacts/workout-visual-qa/review-batches/batch-01/previews/Barbell_Guillotine_Bench_Press",
      "sourceFrames": [
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Guillotine_Bench_Press_male_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Guillotine_Bench_Press_male_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Guillotine_Bench_Press_male_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Guillotine_Bench_Press_male_v2_3.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Guillotine_Bench_Press_female_v2_0.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Guillotine_Bench_Press_female_v2_1.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Guillotine_Bench_Press_female_v2_2.png",
        "/Users/apoorvdarshan/fud-ai/shared/workout-vectors/Barbell_Guillotine_Bench_Press_female_v2_3.png"
      ]
    }
  ]
} as {
  meta: {
    batchNumber: number;
    exerciseCount: number;
    severityCounts: Record<string, number>;
    issueTagCounts: Record<string, number>;
    suggestedRouteCounts: Record<string, number>;
    generatedAt: string;
    workspaceRoot: string;
  };
  exercises: ExerciseRow[];
};

const REVIEW_OPTIONS = [
  { value: "pending", label: "Pending" },
  { value: "accept_as_is", label: "Accept as-is" },
  { value: "script_fix", label: "Script fix" },
  { value: "redraw", label: "Redraw" },
  { value: "defer", label: "Defer" },
];

const SORT_OPTIONS = [
  { value: "index", label: "Batch order" },
  { value: "exerciseId", label: "Exercise name" },
  { value: "severity", label: "Severity" },
  { value: "suggestedRoute", label: "Suggested route" },
  { value: "decision", label: "Your decision" },
];

function severityTone(severity: string): "warning" | "neutral" {
  if (severity === "critical") return "warning";
  if (severity === "major") return "neutral";
  return "neutral";
}

function routeTone(route: string): "info" | "warning" | "neutral" {
  if (route === "script_fix") return "info";
  if (route === "redraw") return "warning";
  if (route === "defer") return "neutral";
  return "neutral";
}

export default function WorkoutAuditBatchReview() {
  const theme = useHostTheme();
  const dispatch = useCanvasAction();
  const [search, setSearch] = useCanvasState("search", "");
  const [severityFilter, setSeverityFilter] = useCanvasState("severityFilter", "all");
  const [tagFilter, setTagFilter] = useCanvasState("tagFilter", "all");
  const [routeFilter, setRouteFilter] = useCanvasState("routeFilter", "all");
  const [sortKey, setSortKey] = useCanvasState("sortKey", "index");
  const [decisions, setDecisions] = useCanvasState<Record<string, ReviewDecision>>("decisions", {});

  const tagOptions = useMemo(
    () => [
      { value: "all", label: "All issue tags" },
      ...Object.keys(BATCH.meta.issueTagCounts)
        .sort()
        .map((tag) => ({ value: tag, label: `${tag} (${BATCH.meta.issueTagCounts[tag]})` })),
    ],
    [],
  );

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    let rows = BATCH.exercises.filter((row) => {
      if (severityFilter !== "all" && row.severity !== severityFilter) return false;
      if (tagFilter !== "all" && !row.issueTags.includes(tagFilter)) return false;
      if (routeFilter !== "all" && row.suggestedRoute !== routeFilter) return false;
      if (!q) return true;
      const blob = [row.exerciseId, row.severity, row.suggestedRoute, ...row.issueTags, ...row.findings]
        .join(" ")
        .toLowerCase();
      return blob.includes(q);
    });

    rows = [...rows].sort((a, b) => {
      if (sortKey === "index") return a.index - b.index;
      if (sortKey === "exerciseId") return a.exerciseId.localeCompare(b.exerciseId);
      if (sortKey === "severity") return a.severity.localeCompare(b.severity) || a.index - b.index;
      if (sortKey === "suggestedRoute") return a.suggestedRoute.localeCompare(b.suggestedRoute) || a.index - b.index;
      if (sortKey === "decision") {
        const da = decisions[a.exerciseId] ?? "pending";
        const db = decisions[b.exerciseId] ?? "pending";
        return da.localeCompare(db) || a.index - b.index;
      }
      return a.index - b.index;
    });
    return rows;
  }, [search, severityFilter, tagFilter, routeFilter, sortKey, decisions]);

  const decisionCounts = useMemo(() => {
    const counts: Record<string, number> = { pending: 0 };
    for (const row of BATCH.exercises) {
      const d = decisions[row.exerciseId] ?? "pending";
      counts[d] = (counts[d] ?? 0) + 1;
    }
    return counts;
  }, [decisions]);

  const setDecision = (exerciseId: string, value: string) => {
    setDecisions((prev) => ({ ...prev, [exerciseId]: value as ReviewDecision }));
  };

  return (
    <Stack gap={16} style={{ padding: 16, color: theme.text.primary }}>
      <Stack gap={4}>
        <H1>Workout audit — batch {BATCH.meta.batchNumber}</H1>
        <Text tone="secondary">
          Review production originals on dark/light contact sheets. Audit-only — no repairs run yet.
        </Text>
        <Text tone="tertiary" size="small">
          Generated {BATCH.meta.generatedAt} · {BATCH.meta.exerciseCount} exercises
        </Text>
      </Stack>

      <Grid columns={4} gap={12}>
        <Stat value={BATCH.meta.exerciseCount} label="Exercises in batch" />
        <Stat value={BATCH.meta.severityCounts.critical ?? 0} label="Critical" tone="danger" />
        <Stat value={BATCH.meta.severityCounts.major ?? 0} label="Major" tone="warning" />
        <Stat
          value={`${decisionCounts.pending ?? 0} pending`}
          label="Your review progress"
          tone="info"
        />
      </Grid>

      <Callout tone="info">
        Target: squat-style transparent PNGs readable on light and dark backgrounds with stable 4-frame
        animation. Suggested routes use the local repair scripts first; redraw only when anatomy or
        multi-pose fragments block script fixes.
      </Callout>

      <Stack gap={8}>
        <H2>Filters</H2>
        <Row gap={8} wrap>
          <TextInput
            value={search}
            onChange={setSearch}
            placeholder="Search exercise or finding…"
            style={{ minWidth: 220, flex: 1 }}
          />
          <Select
            value={severityFilter}
            onChange={setSeverityFilter}
            options={[
              { value: "all", label: "All severities" },
              { value: "critical", label: "Critical only" },
              { value: "major", label: "Major only" },
            ]}
            style={{ minWidth: 160 }}
          />
          <Select value={tagFilter} onChange={setTagFilter} options={tagOptions} style={{ minWidth: 180 }} />
          <Select
            value={routeFilter}
            onChange={setRouteFilter}
            options={[
              { value: "all", label: "All routes" },
              ...Object.keys(BATCH.meta.suggestedRouteCounts).map((route) => ({
                value: route,
                label: `${route} (${BATCH.meta.suggestedRouteCounts[route]})`,
              })),
            ]}
            style={{ minWidth: 160 }}
          />
          <Select value={sortKey} onChange={setSortKey} options={SORT_OPTIONS} style={{ minWidth: 160 }} />
        </Row>
        <Text tone="tertiary" size="small">
          Showing {filtered.length} of {BATCH.exercises.length} exercises
        </Text>
      </Stack>

      <Stack gap={8}>
        <H2>Summary table</H2>
        <Table
          headers={["#", "Exercise", "Severity", "Tags", "Suggested route", "Your decision"]}
          rows={filtered.map((row) => [
            String(row.index),
            row.exerciseId,
            row.severity,
            row.issueTags.join(", "),
            row.suggestedRoute,
            decisions[row.exerciseId] ?? "pending",
          ])}
          rowTone={filtered.map((row) => severityTone(row.severity))}
          striped
          stickyHeader
        />
      </Stack>

      <Divider />

      <Stack gap={8}>
        <H2>Exercise details</H2>
        {filtered.map((row) => {
          const decision = decisions[row.exerciseId] ?? "pending";
          return (
            <CollapsibleSection
              key={row.exerciseId}
              title={row.exerciseId}
              count={row.findings.length}
              leading={<Pill tone={severityTone(row.severity)} size="sm">{row.severity}</Pill>}
              trailing={
                <Row gap={8} align="center">
                  <Pill tone={routeTone(row.suggestedRoute)} size="sm">{row.suggestedRoute}</Pill>
                  <Select
                    value={decision}
                    onChange={(value) => setDecision(row.exerciseId, value)}
                    options={REVIEW_OPTIONS}
                    style={{ minWidth: 140 }}
                  />
                </Row>
              }
            >
              <Stack gap={8}>
                <Text weight="semibold">Findings</Text>
                <Stack gap={4}>
                  {row.findings.map((finding, i) => (
                    <Text key={`${row.exerciseId}-f-${i}`} size="small">
                      • {finding}
                    </Text>
                  ))}
                </Stack>
                <Row gap={8} wrap>
                  {row.issueTags.map((tag) => (
                    <Pill key={tag} tone="neutral" size="sm">{tag}</Pill>
                  ))}
                </Row>
                <Row gap={8} wrap>
                  <Button variant="secondary" onClick={() => dispatch({ type: "openFile", path: row.maleContact })}>
                    Male contact sheet
                  </Button>
                  <Button variant="secondary" onClick={() => dispatch({ type: "openFile", path: row.femaleContact })}>
                    Female contact sheet
                  </Button>
                  <Button variant="ghost" onClick={() => dispatch({ type: "openFile", path: row.previewDir })}>
                    Preview folder
                  </Button>
                </Row>
                <Text tone="tertiary" size="small">
                  Source frames (production originals):
                </Text>
                <Stack gap={2}>
                  {row.sourceFrames.map((frame) => (
                    <Link key={frame} href={`file://${frame}`}>
                      {frame.split("/").pop()}
                    </Link>
                  ))}
                </Stack>
              </Stack>
            </CollapsibleSection>
          );
        })}
      </Stack>
    </Stack>
  );
}
