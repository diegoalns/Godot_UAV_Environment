# Create the graph
import networkx as nx
from geopy.distance import geodesic
import numpy as np
import plotly.graph_objects as go  # Import Plotly

# Define the bounding box for geographic coordinates
min_lat, max_lat = 40.6042, 40.6125
min_lon, max_lon = -73.9458, -73.9292
min_alt, max_alt = 0.001, 0.0015

# Define grid dimensions
n_lat, n_lon, n_alt = 10, 10, 3

# Generate grid points using NumPy's linspace
lats = np.linspace(min_lat, max_lat, n_lat)
lons = np.linspace(min_lon, max_lon, n_lon)
alts = np.linspace(min_alt, max_alt, n_alt)

# Create node identifiers and their geographic positions
nodes = [(i, j, k) for i in range(n_lat) for j in range(n_lon) for k in range(n_alt)]
pos = {(i, j, k): (lats[i], lons[j], alts[k]) for i in range(n_lat) for j in range(n_lon) for k in range(n_alt)}





availability = {node: np.random.random() < 0.8 for node in nodes}  # Randomly assign availability



# Create an empty directed graph using NetworkX
G = nx.DiGraph()

# Add all nodes to the graph
G.add_nodes_from(nodes)

# Set node attributes for geographic coordinates
nx.set_node_attributes(G, pos, 'pos')
nx.set_node_attributes(G, availability, 'available')

# Define a function to calculate the slant range (3D distance) between two points
def slant_range(p1, p2):
    dist_2d = geodesic(p1[:2], p2[:2]).meters
    dalt = p2[2] - p1[2]
    return np.sqrt(dist_2d**2 + (100000*dalt)**2)

# Add edges to connect each node to all its neighbors, including diagonals
for i in range(n_lat):
    for j in range(n_lon):
        for k in range(n_alt):
            for di in [-1, 0, 1]:
                for dj in [-1, 0, 1]:
                    for dk in [-1, 0, 1]:
                        if G.nodes[(i, j, k)]['available'] == False:
                            continue
                        if di == dj == dk == 0:
                            continue
                        ni, nj, nk = i + di, j + dj, k + dk
                        if 0 <= ni < n_lat and 0 <= nj < n_lon and 0 <= nk < n_alt:
                            if G.nodes[(ni, nj, nk)]['available'] == False:
                                continue
                            u, v = (i, j, k), (ni, nj, nk)
                            dist = slant_range(pos[u], pos[v])
                            G.add_edge(u, v, weight=dist)

# Create lists for nodes
node_x = [pos[node][1] for node in G.nodes()]
node_y = [pos[node][0] for node in G.nodes()]
node_z = [pos[node][2] for node in G.nodes()]
node_colors = ['green' if G.nodes[node]['available'] else 'red' for node in G.nodes()]

# Create lists for edges and arrows
edge_x, edge_y, edge_z = [], [], []
arrow_x, arrow_y, arrow_z = [], [], []
arrow_u, arrow_v, arrow_w = [], [], []

for edge in G.edges():
    x0, y0, z0 = pos[edge[0]][1], pos[edge[0]][0], pos[edge[0]][2]
    x1, y1, z1 = pos[edge[1]][1], pos[edge[1]][0], pos[edge[1]][2]

    # Add coordinates for the edge line
    edge_x.extend([x0, x1, None])
    edge_y.extend([y0, y1, None])
    edge_z.extend([z0, z1, None])

    # Direction vector for the arrow
    u_vec = x1 - x0
    v_vec = y1 - y0
    w_vec = z1 - z0

    # Normalize the vector to control arrow size and shape
    magnitude = np.sqrt(u_vec**2 + v_vec**2 + w_vec**2)

    if magnitude > 0:
        u_norm = u_vec / magnitude
        v_norm = v_vec / magnitude
        w_norm = w_vec / magnitude

        # Place the arrow slightly before the end of the line
        arrow_pos_ratio = 0.95
        arrow_x.append(x0 + u_vec * arrow_pos_ratio)
        arrow_y.append(y0 + v_vec * arrow_pos_ratio)
        arrow_z.append(z0 + w_vec * arrow_pos_ratio)

        # Append normalized vectors for consistent arrow shape
        arrow_u.append(u_norm)
        arrow_v.append(v_norm)
        arrow_w.append(w_norm)

# Create the main edge trace (lines)
edge_trace = go.Scatter3d(
    x=edge_x, y=edge_y, z=edge_z,
    line=dict(width=2, color='gray'),
    hoverinfo='none',
    mode='lines'
)

# Create the node trace
node_trace = go.Scatter3d(
    x=node_x, y=node_y, z=node_z,
    mode='markers',
    hoverinfo='text',
    marker=dict(size=5, color=node_colors),
    text=[f"Lat: {pos[n][0]:.4f}<br>Lon: {pos[n][1]:.4f}<br>Alt: {pos[n][2]:.0f}" for n in G.nodes()],
    textposition="top center"
)

# Create the cone trace for the arrows
arrow_trace = go.Cone(
    x=arrow_x, y=arrow_y, z=arrow_z,
    u=arrow_u, v=arrow_v, w=arrow_w,
    sizeref=0.1,  # Keep this value low for a normalized vector
    sizemode="absolute",
    anchor="tip",
    colorscale=[[0, 'red'], [1, 'red']],
    showscale=False
)

# Create the figure and add all traces
fig = go.Figure(data=[edge_trace, node_trace, arrow_trace])

# Customize the layout
fig.update_layout(
    title='Interactive 3D Directed Geographic Lattice Graph',
    scene=dict(
        xaxis_title='Longitude',
        yaxis_title='Latitude',
        zaxis_title='Altitude',
    )
)

# Display the interactive plot
fig.show()

node = (1, 1, 0)  # Specify node
print(f"Attributes of {node}: {G.nodes[node]}")
print(f"Edges of {node}:")
for u, v, data in G.edges(node, data=True):
    print(f"  {u} -> {v}, Weight: {data['weight']:.2f} meters")

for u, v in G.edges():
    print(f"Arc from {u} to {v} with weight {G[u][v]['weight']}" )