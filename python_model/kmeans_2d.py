import numpy as np 

def kmeans(points, centroids, iterations):
    k = len(centroids)

    for iterations in range(iterations):
        clusters = [[] for _ in range(k)]

        #Assign points to the nearest centroid
        for p in points:
           distances = [np.sum((p - c) ** 2) for c in centroids]
           cluster_id = np.argmin(distances)
           clusters[cluster_id].append(p)

        print(f"\nIteration {iterations + 1}")
        for i, cluster in enumerate(clusters):
            print(f"Cluster {i}: {cluster}")

        #Update centroids
        for i in range(k):
            if len(clusters[i]) >0:
                centroids[i] =np.mean(clusters[i], axis=0)

    return centroids, clusters

# Example usage
if __name__ == "__main__":
    #fixed datasets
    points = np.array([[2, 3], [3, 4], [4, 3],
                       [10, 10], [11, 12], [9, 11]])

    centroids = np.array([
        [2, 3],
        [10, 10]
    ])
    final_centroids, clusters = kmeans(points, centroids, iterations=5)
    print("\nFinal Centroids:", final_centroids)

       