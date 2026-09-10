import numpy as np
import cv2
import matplotlib.pyplot as plt
from tkinter import Tk, filedialog

# Hide main tkinter window
Tk().withdraw()

print("Please select an image...")

file_path = filedialog.askopenfilename(
    title="Select an Image",
    filetypes=[("Image Files", "*.jpg *.jpeg *.png *.bmp")]
)

if not file_path:
    print("No file selected!")
    exit()

# Load image (BGR)
image = cv2.imread(file_path)

# Convert BGR → RGB (important for display)
image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

# Resize
image = cv2.resize(image, (32, 32))

# Flatten pixels → shape (N, 3)
pixels = image.reshape(-1, 3)

print("Pixel Shape:", pixels.shape)

# ----------------------------------------
# Hardware-like function (RGB distance)
# ----------------------------------------
def hardware_kmeans_rgb(pixel, centroids):
    distances = []
    
    for c in centroids:
        d = ((pixel[0] - c[0]) ** 2 +
             (pixel[1] - c[1]) ** 2 +
             (pixel[2] - c[2]) ** 2)
        distances.append(d)
    
    return np.argmin(distances)

# ----------------------------------------
# K-Means (RGB)
# ----------------------------------------
K = 3

# Initialize centroids randomly
centroids = pixels[np.random.choice(len(pixels), K, replace=False)]

for _ in range(20):
    clusters = []

    for p in pixels:
        cid = hardware_kmeans_rgb(p, centroids)
        clusters.append(cid)

    clusters = np.array(clusters)

    # Update centroids
    for i in range(K):
        if np.any(clusters == i):
            centroids[i] = np.mean(pixels[clusters == i], axis=0)

# Create segmented image
segmented = centroids[clusters].reshape(image.shape).astype(np.uint8)

# ----------------------------------------
# Display
# ----------------------------------------
plt.figure(figsize=(10,4))

plt.subplot(1,2,1)
plt.imshow(image)
plt.title("Original RGB")
plt.axis('off')

plt.subplot(1,2,2)
plt.imshow(segmented)
plt.title("Segmented RGB (K=3)")
plt.axis('off')

plt.show()

print("Final Centroids:\n", centroids)