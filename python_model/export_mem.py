import cv2
import numpy as np
from tkinter import Tk, filedialog

# ── File picker ──
Tk().withdraw()
print("Select your image for K-Means Hardware Accelerator...")

file_path = filedialog.askopenfilename(
    title="Select Image",
    filetypes=[("Image Files", "*.jpg *.jpeg *.png *.bmp")]
)
if not file_path:
    print("No file selected!")
    exit()

image = cv2.imread(file_path)
image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
image = cv2.resize(image, (32, 32))
pixels = image.reshape(-1, 3).astype(np.float32)

print(f"Image loaded: {file_path}")
print(f"Pixel array shape: {pixels.shape}")

# ─────────────────────────────────────────────
#  K-Means++ centroid initialisation
#  Spreads initial centroids far apart in color
#  space — prevents cluster death problem
# ─────────────────────────────────────────────
K = 4

def kmeans_plus_plus(pixels, K):
    np.random.seed(42)  # fixed seed → reproducible every run
    centroids = []

    # Pick first centroid randomly
    idx = np.random.randint(0, len(pixels))
    centroids.append(pixels[idx].copy())

    for _ in range(K - 1):
        # Compute distance from each pixel to nearest centroid
        dists = np.array([
            min(np.sum((p - c)**2) for c in centroids)
            for p in pixels
        ])
        # Pick next centroid with probability proportional to distance²
        probs = dists / dists.sum()
        cumulative = np.cumsum(probs)
        r = np.random.rand()
        next_idx = np.searchsorted(cumulative, r)
        centroids.append(pixels[next_idx].copy())

    return np.array(centroids, dtype=np.uint8)

centroids = kmeans_plus_plus(pixels, K)

print("\nInitial centroids (K-Means++ — spread across color space):")
for i, c in enumerate(centroids):
    print(f"  C{i}: R={c[0]:3d}  G={c[1]:3d}  B={c[2]:3d}  →  {c[0]:02X}{c[1]:02X}{c[2]:02X}")

# ── Export pixels.mem ──
with open("pixels.mem", "w") as f:
    for r, g, b in pixels.astype(np.uint8):
        f.write(f"{r:02X}{g:02X}{b:02X}\n")
print(f"\npixels.mem written — {len(pixels)} pixels")

# ── Export centroids.mem ──
with open("centroids.mem", "w") as f:
    for r, g, b in centroids:
        f.write(f"{int(r):02X}{int(g):02X}{int(b):02X}\n")
print("centroids.mem written — 4 centroids")

# ── Preview ──
print("\nFirst 5 pixels:")
for i, (r, g, b) in enumerate(pixels[:5].astype(np.uint8)):
    print(f"  P{i}: R={r:3d} G={g:3d} B={b:3d} → {r:02X}{g:02X}{b:02X}")

print("\nDone. Copy pixels.mem and centroids.mem to Vivado xsim folder.")
print("centroids.mem uses K-Means++ — clusters will not die.")