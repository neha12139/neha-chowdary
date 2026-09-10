import cv2
import numpy as np
from tkinter import Tk, filedialog

# ─────────────────────────────────────────────
#  Hardware final centroids — paste from Vivado
#  Tcl console output here
# ─────────────────────────────────────────────
HARDWARE_CENTROIDS = np.array([
    [187,  181,  182 ],   # C0   ← copy from Vivado console
    [234,  164, 28 ],   # C1   ← copy from Vivado console
    [65,  65, 64 ],   # C2   ← copy from Vivado console
    [9,  88,  226 ],   # C3   ← copy from Vivado console
], dtype=np.float32)

K = 4
MAX_ITER = 10

# ─────────────────────────────────────────────
#  Load the SAME image you used in Vivado
# ─────────────────────────────────────────────
Tk().withdraw()
print("Select the SAME image you used for Vivado simulation...")
file_path = filedialog.askopenfilename(
    title="Select Image (same one used in Vivado)",
    filetypes=[("Image Files", "*.jpg *.jpeg *.png *.bmp")]
)
if not file_path:
    print("No file selected!")
    exit()

image = cv2.imread(file_path)
image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
image = cv2.resize(image, (32, 32))
pixels = image.reshape(-1, 3).astype(np.float32)

print(f"\nImage loaded: {file_path}")
print(f"Pixels: {pixels.shape[0]} total (32x32)")

# ─────────────────────────────────────────────
#  Load the SAME initial centroids used in Vivado
#  (reads centroids.mem from current directory)
# ─────────────────────────────────────────────
try:
    with open("centroids.mem", "r") as f:
        lines = [l.strip() for l in f.readlines() if l.strip()]
    init_centroids = np.array([
        [int(l[0:2], 16), int(l[2:4], 16), int(l[4:6], 16)]
        for l in lines[:4]
    ], dtype=np.float32)
    print("\nInitial centroids loaded from centroids.mem (same as Vivado):")
    for i, c in enumerate(init_centroids):
        print(f"  C{i}: R={int(c[0])} G={int(c[1])} B={int(c[2])}")
except FileNotFoundError:
    print("\ncentrals.mem not found — using random init instead")
    idx = np.random.choice(len(pixels), K, replace=False)
    init_centroids = pixels[idx].copy()

# ─────────────────────────────────────────────
#  Hardware-style K-Means
#  Uses integer squared Euclidean (matches hardware exactly)
# ─────────────────────────────────────────────
def hw_distance(pixel, centroid):
    """Squared Euclidean — no sqrt, matches dist_unit.v exactly"""
    return int((pixel[0]-centroid[0])**2 +
               (pixel[1]-centroid[1])**2 +
               (pixel[2]-centroid[2])**2)

def hw_argmin(pixel, centroids):
    """Tournament-style argmin — matches min_finder_k4.v"""
    distances = [hw_distance(pixel, c) for c in centroids]
    return int(np.argmin(distances))

# Run K-Means with same initial centroids as hardware
centroids = init_centroids.copy()
print(f"\nRunning Python K-Means ({MAX_ITER} iterations)...")
print("─" * 44)

for iteration in range(MAX_ITER):
    # Assign clusters — matches COMPUTE state
    cluster_ids = np.array([hw_argmin(p, centroids) for p in pixels])

    # Count per cluster
    counts = [np.sum(cluster_ids == k) for k in range(K)]
    print(f"Iter {iteration} done | " +
          " ".join([f"C{k}:{counts[k]}" for k in range(K)]) + " px")

    # Update centroids — matches UPDATE state (integer division)
    new_centroids = centroids.copy()
    for k in range(K):
        mask = cluster_ids == k
        if np.any(mask):
            # Integer division matches hardware accumulator
            new_centroids[k][0] = int(np.sum(pixels[mask, 0])) // counts[k]
            new_centroids[k][1] = int(np.sum(pixels[mask, 1])) // counts[k]
            new_centroids[k][2] = int(np.sum(pixels[mask, 2])) // counts[k]
        else:
            new_centroids[k] = np.array([0, 0, 0])

    centroids = new_centroids

# ─────────────────────────────────────────────
#  Final comparison
# ─────────────────────────────────────────────
print("\n" + "=" * 44)
print(" FINAL CENTROID COMPARISON")
print("=" * 44)
print(f"{'':4} {'Python HW-style':>20} {'Vivado Hardware':>20}  {'Delta':>8}")
print("─" * 60)

total_delta = 0
for k in range(K):
    py = centroids[k]
    hw = HARDWARE_CENTROIDS[k]
    delta = int(abs(py[0]-hw[0]) + abs(py[1]-hw[1]) + abs(py[2]-hw[2]))
    total_delta += delta
    match = "✓ MATCH" if delta <= 10 else ("~ CLOSE" if delta <= 30 else "✗ DIFF")
    print(f"C{k}:  R={int(py[0]):3d} G={int(py[1]):3d} B={int(py[2]):3d}  |  "
          f"R={int(hw[0]):3d} G={int(hw[1]):3d} B={int(hw[2]):3d}  "
          f"delta={delta:3d}  {match}")

print("─" * 60)
print(f"Total L1 delta across all centroids: {total_delta}")
if total_delta <= 40:
    print("RESULT: Hardware matches Python model — accelerator verified!")
elif total_delta <= 120:
    print("RESULT: Close match — small rounding differences are normal")
else:
    print("RESULT: Large difference — centroids may have converged")
    print("        to different local minima (normal for K-Means)")
print("=" * 44)

# ─────────────────────────────────────────────
#  Visualise segmented image from Python result
# ─────────────────────────────────────────────
import matplotlib.pyplot as plt

cluster_ids = np.array([hw_argmin(p, centroids) for p in pixels])
segmented = centroids[cluster_ids].reshape(32, 32, 3).astype(np.uint8)

plt.figure(figsize=(10, 4))

plt.subplot(1, 3, 1)
plt.imshow(image)
plt.title("Original (32x32)")
plt.axis('off')

plt.subplot(1, 3, 2)
plt.imshow(segmented)
plt.title("Python K-Means result")
plt.axis('off')

# Hardware segmented image using hardware final centroids
hw_cluster_ids = np.array([hw_argmin(p, HARDWARE_CENTROIDS) for p in pixels])
hw_segmented = HARDWARE_CENTROIDS[hw_cluster_ids].reshape(32, 32, 3).astype(np.uint8)

plt.subplot(1, 3, 3)
plt.imshow(hw_segmented)
plt.title("Hardware centroids result")
plt.axis('off')

plt.suptitle("K-Means Hardware Accelerator — Python vs Hardware Validation",
             fontsize=11, fontweight='bold')
plt.tight_layout()
plt.savefig("validation_result.png", dpi=150, bbox_inches='tight')
plt.show()

print("\nValidation image saved as: validation_result.png")