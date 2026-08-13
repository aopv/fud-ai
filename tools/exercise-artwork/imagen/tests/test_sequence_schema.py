from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
import hashlib
import random
from pathlib import Path

from PIL import Image


TOOL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL))

from SequenceArtworkSchema import (  # noqa: E402
    alignment_drift, alignment_metadata, normalized_pose_interpolation,
    validate_job_sequences,
)


def job(exercise: str, frame: int, count: int) -> dict:
    value = {
        "jobID": f"{exercise}__f{frame}__female", "exerciseID": exercise,
        "gender": "female", "frameIndex": frame,
    }
    if count == 2:
        value.update({"sourceImagePath": f"source{frame}.jpg", "sourceImageSHA256": str(frame)})
    else:
        value.update({
            "sequence": {"schemaVersion": 2, "frameCount": 6, "frameIndex": frame,
                         "frameRole": "endpoint" if frame in (0, 5) else "inbetween",
                         "interpolationT": frame / 5, "endpointFrameIndices": [0, 5]},
            "sourceEndpointReferences": [
                {"frameIndex": 0, "path": "source0.jpg", "sha256": "zero"},
                {"frameIndex": 5, "path": "source1.jpg", "sha256": "five"},
            ],
        })
    return value


class SequenceSchemaTests(unittest.TestCase):
    def test_legacy_and_sequence_manifests(self) -> None:
        self.assertEqual(validate_job_sequences([job("Legacy", i, 2) for i in range(2)])["schemaVersion"], 1)
        result = validate_job_sequences([job("Motion", i, 6) for i in range(6)])
        self.assertEqual((result["schemaVersion"], result["frameCounts"]), (2, [6]))

    def test_rejects_missing_or_mislabelled_frame(self) -> None:
        jobs = [job("Motion", i, 6) for i in range(6)]
        jobs[2]["sequence"]["frameRole"] = "endpoint"
        with self.assertRaisesRegex(ValueError, "Invalid frame role"):
            validate_job_sequences(jobs)

    def test_interpolation_and_alignment_drift(self) -> None:
        first = {"hip": [0.0, 0.0], "wrist": [0.0, 1.0]}
        second = {"hip": [1.0, 2.0], "wrist": [2.0, 3.0]}
        self.assertEqual(normalized_pose_interpolation(first, second, 0.5)["wrist"], [1.0, 2.0])
        pose = {"joints": {"leftHip": [0.4, 0.6], "rightHip": [0.6, 0.6],
                           "leftShoulder": [0.4, 0.4], "rightShoulder": [0.6, 0.4]}}
        aligned = alignment_metadata(pose)
        self.assertTrue(alignment_drift(aligned, aligned)["passed"])
        moved = dict(aligned); moved["pelvisAnchor"] = [0.7, 0.6]
        self.assertFalse(alignment_drift(aligned, moved)["passed"])


class MigrationFixtureTests(unittest.TestCase):
    def test_endpoint_state_and_evidence_migrate_to_frame_five(self) -> None:
        repo = TOOL.parents[2]
        with tempfile.TemporaryDirectory(dir=repo, prefix="sequence-fixture-") as directory:
            root = Path(directory)
            images = root / "images"; images.mkdir()
            asset = root / "asset"; (asset / "references").mkdir(parents=True)
            for gender in ("male", "female"):
                Image.new("RGBA", (32, 32), (10, 20, 30, 255)).save(asset / "references" / f"{gender}.png")
            records = []
            statuses = ["complete", "qa_failed", "pending", "blocked_source"]
            old_jobs = []
            state_jobs = {}
            manual_jobs = {}
            report_results = {}
            for exercise_number, status in enumerate(statuses):
                exercise = f"Fixture{exercise_number}"
                filenames = [f"{exercise}_{index}.jpg" for index in range(2)]
                for filename in filenames:
                    Image.new("RGB", (32, 32), (100, 120, 140)).save(images / filename)
                records.append({"id": exercise, "name": exercise, "images": filenames})
                for gender in ("male", "female"):
                    for frame in range(2):
                        job_id = f"{exercise}__f{frame}__{gender}"
                        old_jobs.append({"jobID": job_id})
                        state_jobs[job_id] = {
                            "jobFingerprint": "old", "status": status, "attempts": 1,
                            "qaStatus": "accepted" if status == "complete" else "rejected" if status == "qa_failed" else None,
                            "generatedInputPath": f"{asset.relative_to(repo)}/raw/{gender}/{exercise}/{frame}.png",
                            "outputSHA256": "evidence",
                        }
                        manual_jobs[job_id] = {"artifactFree": status == "complete", "jobID": job_id}
                        report_results[job_id] = {"status": status, "jobID": job_id,
                                                  "outputPath": f"x/{exercise}/{frame}.png"}
                # Only one exercise has actual endpoint artifacts; migration must retain exact bytes.
                if exercise_number == 0:
                    for tree in ("frames", "raw"):
                        path = asset / tree / "female" / exercise / "1.png"
                        path.parent.mkdir(parents=True, exist_ok=True)
                        Image.new("RGBA", (32, 32), (20, 30, 40, 255)).save(path)
                        if tree == "frames":
                            state_jobs[f"{exercise}__f1__female"]["outputSHA256"] = hashlib.sha256(
                                path.read_bytes()).hexdigest()
            dataset = root / "dataset.json"; dataset.write_text(json.dumps(records))
            jobs_path = root / "jobs.jsonl"
            jobs_path.write_text("".join(json.dumps(value) + "\n" for value in old_jobs))
            state = root / "state.json"; state.write_text(json.dumps({"schemaVersion": 1, "jobs": state_jobs}))
            manual = root / "manual.json"; manual.write_text(json.dumps({"schemaVersion": 1, "jobs": manual_jobs}))
            report = root / "report.json"; report.write_text(json.dumps({"schemaVersion": 1, "results": report_results}))
            metadata = root / "meta.json"
            command = [
                sys.executable, str(TOOL / "MigrateEndpointQueueToSequences.py"),
                "--dataset", str(dataset), "--images", str(images), "--asset-root", str(asset),
                "--jobs", str(jobs_path), "--metadata", str(metadata), "--state", str(state),
                "--manual-reviews", str(manual), "--report", str(report),
                "--expected-exercise-count", str(len(records)), "--apply",
            ]
            completed = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
            migrated = json.loads(state.read_text())["jobs"]
            self.assertEqual(len(migrated), len(records) * 2 * 6)
            self.assertEqual(migrated["Fixture0__f5__female"]["status"], "complete")
            self.assertEqual(migrated["Fixture1__f5__female"]["status"], "qa_failed")
            self.assertEqual(migrated["Fixture2__f5__female"]["status"], "pending")
            self.assertEqual(migrated["Fixture3__f5__female"]["status"], "blocked_source")
            self.assertEqual(migrated["Fixture3__f2__female"]["status"], "blocked_source")
            self.assertEqual(migrated["Fixture0__f1__female"]["status"], "pending")
            self.assertTrue((asset / "frames/female/Fixture0/5.png").is_file())
            self.assertFalse((asset / "frames/female/Fixture0/1.png").exists())
            migrated_manual = json.loads(manual.read_text())["jobs"]
            migrated_report = json.loads(report.read_text())["results"]
            self.assertEqual(migrated_manual["Fixture0__f5__female"]["jobID"], "Fixture0__f5__female")
            self.assertEqual(migrated_report["Fixture0__f5__female"]["jobID"], "Fixture0__f5__female")
            self.assertTrue(migrated_report["Fixture0__f5__female"]["outputPath"].endswith("/5.png"))
            moved = asset / "frames/female/Fixture0/5.png"
            self.assertEqual(migrated["Fixture0__f5__female"]["outputSHA256"],
                             hashlib.sha256(moved.read_bytes()).hexdigest())
            exported = subprocess.run([
                sys.executable, str(TOOL / "ExportImagenJobsForWorker.py"),
                "--jobs", str(jobs_path), "--gender", "female",
                "--job-id", "Fixture0__f2__female",
            ], check=True, capture_output=True, text=True)
            payload = json.loads(exported.stdout)
            self.assertEqual(len(payload["referencedImagePaths"]), 3)
            self.assertEqual(payload["contract"]["sequence"]["interpolationT"], 0.4)


class PackagingFixtureTests(unittest.TestCase):
    def test_six_frame_package_verify_and_stagers(self) -> None:
        repo = TOOL.parents[2]
        with tempfile.TemporaryDirectory(dir=repo, prefix="package-fixture-") as directory:
            root = Path(directory)
            refs = []
            for endpoint in (0, 5):
                path = root / f"source{endpoint}.jpg"
                Image.new("RGB", (32, 32), (80 + endpoint, 90, 100)).save(path)
                refs.append({"frameIndex": endpoint, "path": path.relative_to(repo).as_posix(),
                             "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
            jobs = []
            states = {}
            randomizer = random.Random(42)
            for frame in range(6):
                value = job("Sequence", frame, 6)
                value.update({
                    "style": "fud-flat-raster-v1",
                    "outputPath": (root / "masters" / f"{frame}.png").relative_to(repo).as_posix(),
                    "sourceEndpointReferences": refs,
                })
                master = repo / value["outputPath"]
                master.parent.mkdir(parents=True, exist_ok=True)
                pixels = bytearray(randomizer.randrange(256) for _ in range(64 * 64 * 3))
                generated = Image.frombytes("RGB", (64, 64), bytes(pixels)).resize(
                    (1024, 1024), Image.Resampling.BILINEAR).convert("RGBA")
                alpha = Image.new("L", generated.size, 255)
                alpha.paste(0, (0, 0, 128, 128))
                generated.putalpha(alpha)
                generated.save(master)
                jobs.append(value)
                states[value["jobID"]] = {
                    "status": "complete", "qaStatus": "accepted",
                    "outputSHA256": hashlib.sha256(master.read_bytes()).hexdigest(),
                    "sequenceQA": {
                        "passed": True, "sequenceComplete": True,
                        "alignment": {"fixture": True},
                        "driftFromPrevious": None if frame == 0 else {"passed": True},
                    },
                }
            jobs_path = root / "jobs.jsonl"
            jobs_path.write_text("".join(json.dumps(value) + "\n" for value in jobs))
            state_path = root / "state.json"; state_path.write_text(json.dumps({"jobs": states}))
            package = root / "package"; index = package / "index.json"
            subprocess.run([sys.executable, str(TOOL / "PackageAcceptedExerciseArtwork.py"),
                            "--jobs", str(jobs_path), "--state", str(state_path),
                            "--output-root", str(package), "--index", str(index)], check=True)
            subprocess.run([sys.executable, str(TOOL / "VerifyPackagedExerciseArtwork.py"),
                            "--jobs", str(jobs_path), "--state", str(state_path),
                            "--package-root", str(package), "--index", str(index)], check=True)
            data = json.loads(index.read_text())
            self.assertEqual([frame["frameIndex"] for frame in data["entries"][0]["frames"]], list(range(6)))
            self.assertEqual((data["entries"][0]["frameDurationMs"],
                              data["entries"][0]["playback"],
                              data["entries"][0]["sequenceVersion"]), (120, "pingPong", 1))
            android = root / "android"
            subprocess.run([sys.executable, str(TOOL / "StageAcceptedAndroidFrames.py"),
                            "--jobs", str(jobs_path), "--state", str(state_path),
                            "--package-root", str(package), "--index", str(index),
                            "--destination", str(android)], check=True)
            ios = root / "ios"; ios_index = root / "ios-index.json"
            subprocess.run([sys.executable, str(TOOL / "StageAcceptedIOSFrames.py"),
                            "--package-index", str(index), "--state", str(state_path),
                            "--destination", str(ios), "--index", str(ios_index)], check=True)
            self.assertEqual(len(list(android.rglob("*.webp"))), 6)
            self.assertEqual(len(list(ios.glob("*.webp"))), 6)


if __name__ == "__main__":
    unittest.main()
