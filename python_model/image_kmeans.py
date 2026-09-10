import numpy as np
import cv2
import matplotlib.pyplot as plt
from tkinter import Tk, filedialog

# Hide main tkinter window
Tk().withdraw()

print("Please select an image...")

# Open file dialog
file_path = filedialog.askopenfilename(
    title="Select an Image",
    filetypes=[("Image Files", "*.jpg *.jpeg *.png *.bmp")]
)

# Check if user selected a file
if not file_path:
    print("No file selected!")
    exit()

# Load image
image = cv2.imread(file_path)

# Convert to grayscale
gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

# Resize to 32x32
gray = cv2.resize(gray, (32, 32))

# Flatten image into data points
pixels = gray.reshape(-1, 1)

print("Selected file:", file_path)
print("Pixel Data Shape:", pixels.shape)
print("First 10 pixels:\n", pixels[:10])

# ------------------------------------------------
# ✅ UPDATED HARDWARE-LIKE FUNCTION (for 3 clusters)
# ------------------------------------------------
def hardware_kmeans_k3(pixel, centroids):
    distances = []
    
    for c in centroids:
        d = (pixel - c[0]) ** 2
        distances.append(d)
    
    # return index of minimum distance
    return np.argmin(distances)

# -------------------------------
# K-Means Clustering (K = 3)
# -------------------------------
K = 3

# Better centroid initialization (3 values)
centroids = np.array([[30], [120], [220]])

for _ in range(20):
    clusters_hw = []

    # Assign clusters (hardware-style)
    for p in pixels:
        cluster_id = hardware_kmeans_k3(p[0], centroids)
        clusters_hw.append(cluster_id)

    clusters = np.array(clusters_hw)

    # Update centroids
    for i in range(K):
        if np.any(clusters == i):
            centroids[i] = np.mean(pixels[clusters == i])

# Create segmented image
segmented = centroids[clusters].reshape(gray.shape)

# Create labeled segmentation (0, 127, 255)
segmented_levels = (clusters.reshape(gray.shape) * (255 // (K - 1)))

# -------------------------------
# Display Results
# -------------------------------
plt.figure(figsize=(12,4))

# Original
plt.subplot(1,3,1)
plt.imshow(gray, cmap='gray')
plt.title("Original (32x32)")
plt.axis('off')

# Segmented (grayscale)
plt.subplot(1,3,2)
plt.imshow(segmented, cmap='gray')
plt.title("Segmented (K=3)")
plt.axis('off')

# Multi-level segmentation
plt.subplot(1,3,3)
plt.imshow(segmented_levels, cmap='gray')
plt.title("3-Level Output")
plt.axis('off')

plt.show()

# Print final centroids
print("Final Centroids:", centroids)