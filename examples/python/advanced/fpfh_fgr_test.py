#!/usr/bin/env python3
"""Manual smoke test: FPFH + Fast Global Registration on random data.

Builds a random source cloud, makes the target a copy rigidly transformed by a
known ground-truth pose (plus optional noise), then runs the
estimate_normals -> compute_fpfh_feature -> FGR pipeline and checks that the
recovered transform matches the ground truth.

Run with any environment that has cupoch installed, e.g.:
    python examples/python/advanced/fpfh_fgr_test.py
    python examples/python/advanced/fpfh_fgr_test.py --npoints 20000 --noise 0.002

Exit code 0 = pipeline recovered the pose within tolerance, non-zero = failure.
"""
import argparse
import sys

import numpy as np

import cupoch as cph


def rigid_transform(axis, angle_deg, translation):
    """4x4 homogeneous transform from an axis-angle rotation + translation."""
    axis = np.asarray(axis, dtype=np.float64)
    axis = axis / np.linalg.norm(axis)
    theta = np.deg2rad(angle_deg)
    x, y, z = axis
    c, s, C = np.cos(theta), np.sin(theta), 1.0 - np.cos(theta)
    R = np.array([
        [c + x * x * C,     x * y * C - z * s, x * z * C + y * s],
        [y * x * C + z * s, c + y * y * C,     y * z * C - x * s],
        [z * x * C - y * s, z * y * C + x * s, c + z * z * C],
    ])
    T = np.eye(4)
    T[:3, :3] = R
    T[:3, 3] = translation
    return T


def make_cloud(points_np):
    pc = cph.geometry.PointCloud()
    pc.points = cph.utility.Vector3fVector(points_np.astype(np.float32))
    return pc


def rotation_angle_deg(R):
    cos_t = np.clip((np.trace(R) - 1.0) / 2.0, -1.0, 1.0)
    return np.rad2deg(np.arccos(cos_t))


def main():
    ap = argparse.ArgumentParser(description="FPFH + FGR pipeline smoke test")
    ap.add_argument("--npoints", type=int, default=5000)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--noise", type=float, default=0.001,
                    help="stddev of Gaussian noise added to the target (world units)")
    ap.add_argument("--feature-radius", type=float, default=0.25,
                    help="FPFH neighbourhood radius")
    ap.add_argument("--feature-max-nn", type=int, default=100,
                    help="FPFH neighbourhood cap (KDTreeSearchParamRadius max_nn)")
    ap.add_argument("--max-corr-dist", type=float, default=0.075,
                    help="FGR maximum correspondence distance")
    ap.add_argument("--rot-tol-deg", type=float, default=5.0)
    ap.add_argument("--trans-tol", type=float, default=0.05)
    args = ap.parse_args()

    print(f"cupoch {cph.__version__}, numpy {np.__version__}")
    rng = np.random.default_rng(args.seed)

    # Random source cloud in a unit cube. Source/target share identical local
    # structure (target is a transformed copy), so FPFH descriptors at
    # corresponding points match even though the geometry itself is unstructured.
    src_np = rng.random((args.npoints, 3))

    gt_T = rigid_transform(axis=[0.3, 0.7, 0.5], angle_deg=35.0,
                           translation=[0.20, -0.15, 0.10])
    print("Ground-truth transform:\n", np.array_str(gt_T, precision=4, suppress_small=True))

    tgt_np = (src_np @ gt_T[:3, :3].T) + gt_T[:3, 3]
    if args.noise > 0:
        tgt_np = tgt_np + rng.normal(0.0, args.noise, tgt_np.shape)

    source = make_cloud(src_np)
    target = make_cloud(tgt_np)

    knn = cph.geometry.KDTreeSearchParamKNN(knn=30)
    source.estimate_normals(knn)
    target.estimate_normals(knn)

    radius = cph.geometry.KDTreeSearchParamRadius(args.feature_radius, args.feature_max_nn)
    src_feat = cph.registration.compute_fpfh_feature(source, radius)
    tgt_feat = cph.registration.compute_fpfh_feature(target, radius)
    print(f"FPFH computed (radius={args.feature_radius})")

    opt = cph.registration.FastGlobalRegistrationOption(
        maximum_correspondence_distance=args.max_corr_dist,
        iteration_number=64,
    )
    result = cph.registration.registration_fast_based_on_feature_matching(
        source, target, src_feat, tgt_feat, opt)

    est_T = np.asarray(result.transformation, dtype=np.float64)
    print("\nEstimated transform:\n", np.array_str(est_T, precision=4, suppress_small=True))
    print(f"\nfitness          = {result.fitness:.4f}")
    print(f"inlier_rmse      = {result.inlier_rmse:.6f}")
    print(f"correspondences  = {len(result.correspondence_set)}")

    R_err = est_T[:3, :3] @ gt_T[:3, :3].T
    rot_err_deg = rotation_angle_deg(R_err)
    trans_err = float(np.linalg.norm(est_T[:3, 3] - gt_T[:3, 3]))
    print(f"\nrotation error    = {rot_err_deg:.3f} deg (tol {args.rot_tol_deg})")
    print(f"translation error = {trans_err:.4f}     (tol {args.trans_tol})")

    ok = (rot_err_deg <= args.rot_tol_deg
          and trans_err <= args.trans_tol
          and result.fitness > 0.0)
    print("\nRESULT:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
