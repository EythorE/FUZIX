import argparse
import os
from pathlib import Path
from math import ceil

import numpy as np
from PIL import Image
from sklearn.cluster import KMeans


def floyd_steinberg_dithering(img, bits_per_channel=3):
    # # Load the image
    img = img.convert('RGB')
    img_array = np.array(img, dtype=np.float64)
    
    height, width = img_array.shape[:2]
    
    # Calculate the number of levels per channel
    levels = 2**bits_per_channel
    # Calculate the quantization step
    quantization_step = 255 / (levels - 1)
    
    for y in range(height):
        for x in range(width):
            # Get old pixel value
            old_pixel = img_array[y, x].copy()
            
            # Calculate new pixel value (quantized)
            new_pixel = np.round(old_pixel / quantization_step) * quantization_step
            new_pixel = np.clip(new_pixel, 0, 255)
            
            # Update image with new pixel
            img_array[y, x] = new_pixel
            
            # Calculate quantization error
            error = old_pixel - new_pixel
            
            # Distribute error to neighboring pixels
            if x + 1 < width:
                img_array[y, x + 1] += error * 7/16
            if y + 1 < height:
                if x - 1 >= 0:
                    img_array[y + 1, x - 1] += error * 3/16
                img_array[y + 1, x] += error * 5/16
                if x + 1 < width:
                    img_array[y + 1, x + 1] += error * 1/16
    
    return Image.fromarray(img_array.astype(np.uint8))
    

# Use K-means to find dominant colors
def quantize_colors(img, n_colors):
    img_array = np.array(img)
    pixels = img_array.reshape(-1, 3)
    kmeans = KMeans(n_clusters=n_colors, random_state=0).fit(pixels)
    palette_colors = ((kmeans.cluster_centers_//32)*32).astype(int)
    
    # Map each pixel to the closest centroid
    indexed_image = kmeans.labels_.reshape(img_array.shape[:2])

    # return indexed_image, palette_colors
    # Not strictly necessary, but keep the first plane as populated as possible
    unique_values, counts = np.unique(indexed_image, return_counts=True)
    np.argsort(counts)
    
    indexed_image_s = np.zeros_like(indexed_image)
    palette_colors_s = np.zeros_like(palette_colors)
    for n,o in enumerate(reversed(np.argsort(counts))):
        indexed_image_s[indexed_image==o] = n
        palette_colors_s[n] = palette_colors[o]
    
    return indexed_image_s, palette_colors_s

# force the image to be square [max_res x max_res]
def resize(img_original, max_res):
    # Resize the original image to fit within max_res while maintaining aspect ratio
    orig_width, orig_height = img_original.size
    if orig_width > orig_height:
        new_width = min(max_res, orig_width)
        new_height = int(orig_height * (new_width / orig_width))
    else:
        new_height = min(max_res, orig_height)
        new_width = int(orig_width * (new_height / orig_height))
    
    # Resize the original image
    resized_img = img_original.resize((new_width, new_height), Image.LANCZOS)
    
    # Create a new black square image
    square_img = Image.new('RGB', (max_res, max_res), color='black')
    
    # Calculate position to paste the resized image (centered)
    paste_x = (max_res - new_width) // 2
    paste_y = (max_res - new_height) // 2
    
    # Paste the resized image onto the black background
    square_img.paste(resized_img, (paste_x, paste_y))
    
    return square_img

#def resize(img_original, max_res):
#    orig_width, orig_height = img_original.size
#
#    if orig_width > orig_height:
#        # new_width = min(320, orig_width)
#        new_width = min(max_res, orig_width)
#        new_height = int(orig_height * (new_width / orig_width))
#    else:
#        # new_height = min(224, orig_height)
#        new_height = min(max_res, orig_height)
#        new_width = int(orig_width * (new_height / orig_height))
#    
#    img = img_original.resize((new_width, new_height), Image.LANCZOS)
#    return img


def split_palette(indexed_image, palette, n_planes, n_colors_per_palette):
    # split into 15 colours per pallet [1-15], single image per palette
    palettes = np.array_split(palette, n_planes)
    # add the transparent color as 0
    palettes = [np.concatenate([np.zeros((1,3), dtype=int), p]) for p in palettes]
    
    planes = []
    for p in range(n_planes):
        plane = np.zeros_like(indexed_image)
        mask = (indexed_image >= p*n_colors_per_palette) & (indexed_image < (p+1)*n_colors_per_palette)
        # 0 is transparent
        plane[mask] = indexed_image[mask] - (p*n_colors_per_palette) + 1
        planes.append(plane)
    return planes, palettes


def get_tile_images(image, width=8, height=8):
    _nrows, _ncols = image.shape
    _size = image.size
    _strides = image.strides

    nrows, _m = divmod(_nrows, height)
    ncols, _n = divmod(_ncols, width)
    if _m != 0 or _n != 0:
        return None

    return np.lib.stride_tricks.as_strided(
        np.ravel(image),
        shape=(nrows, ncols, height, width),
        strides=(height * _strides[0], width * _strides[1], *_strides),
        writeable=False
    )


def tiles_to_plane_tilemap(tiles):
    # in nibbles
    tilesflat = tiles.astype('uint8').flatten()
    tiles_nibbles = (tilesflat[0::2] << 4) | tilesflat[1::2]
    tiles_bytes = tiles_nibbles.tobytes()
    return tiles_bytes


def tiles_to_sprite_tilemap(tiles):
    sprite_tiles = []
    tile_i = 0
    tile_j = 0
    for si in range(0,16,4): # 4 4x4 sprite
        for sj in range(0,16,4):
            for j in range(4): # 4 tiles per sprite from top to bottom
                for i in range(4): # left to right
                    sprite_tiles.append(tiles[si+i, sj+j])
    sprite_tiles = np.array(sprite_tiles)

    # write nibbles
    tilesflat = sprite_tiles.astype('uint8').flatten()
    tiles_nibbles = (tilesflat[0::2] << 4) | tilesflat[1::2]
    tiles_bytes = tiles_nibbles.tobytes()
    return tiles_bytes


# Each colour is a word in binary format 0000 BBB0 GGG0 RRR0
def palette_to_bytes(p):
    p = (p.astype('uint16') // 32)*2
    p[:, 1] *= 16
    p[:, 2] *= 16*16
    
    p = p.sum(axis=1).astype('>u2')
    data_bytes = p.tobytes()
    return data_bytes


def convert_to_blob_bytes(tiled_images, palettes):
    print("blob data:")
    # add the data
    buffer = bytearray()
    
    print(f"palette 0x{len(buffer):08x}")
    for p in palettes:
        buffer.extend(palette_to_bytes(p))
    
    print(f"plane A tilemap 0x{len(buffer):08x}")
    buffer.extend(tiles_to_plane_tilemap(tiled_images[0]))
    
    print(f"plane B tilemap 0x{len(buffer):08x}")
    buffer.extend(tiles_to_plane_tilemap(tiled_images[1]))
    
    print(f"sprite-1 tilemap 0x{len(buffer):08x}")
    buffer.extend(tiles_to_sprite_tilemap(tiled_images[2]))
    
    print(f"sprite-2 tilemap 0x{len(buffer):08x}")
    buffer.extend(tiles_to_sprite_tilemap(tiled_images[3]))
    
    print(f"END 0x{len(buffer):08x} ({round(len(buffer)/1024,2)} kb)")
    
    file_bytes = bytes(buffer)
    
    return file_bytes


def convert_and_show(
    image_path,
    total_palette_colors,
    max_res,
    show=True
):
    img_original = Image.open(image_path)
    print(f"Original image dimensions: {img_original.size[0]}x{img_original.size[1]}")
    
    img_resized = resize(img_original, max_res)
    print(f"Resized to {img_resized.size[0]}x{img_resized.size[1]}")
    
    img_dithered = floyd_steinberg_dithering(img_resized, bits_per_channel=3)

    # kmeans
    indexed_image, palette_colors = quantize_colors(img_dithered, n_colors=total_palette_colors)
    print(f"quantized to {len(palette_colors)} colors")
    if show:
        display_results(img_original, img_resized, img_dithered, palette_colors[indexed_image])
    return indexed_image, palette_colors


def display_results(original, resized, dithered, quantized):
    import matplotlib.pyplot as plt
    
    # Display the original and quantized images side by side
    plt.figure(figsize=(20, 5))
    
    plt.subplot(1, 4, 1)
    plt.imshow(original)
    plt.title('Original Image')
    plt.axis('off')

    plt.subplot(1, 4, 2)
    plt.imshow(resized)
    plt.title(f'resized Image')
    plt.axis('off')
    
    plt.subplot(1, 4, 3)
    plt.imshow(dithered)
    plt.title(f'9bit dithered Image')
    plt.axis('off')

    plt.subplot(1, 4, 4)
    plt.imshow(quantized)
    plt.title(f'palette Quantized Image')
    plt.axis('off')
    
    plt.tight_layout()
    plt.show()


def show_planes(planes, palettes):
    import matplotlib.pyplot as plt
    from matplotlib.colors import ListedColormap
    
    n_planes = len(planes)
    fig, axs = plt.subplots(1, n_planes+1, figsize=(n_planes*6,5))
    
    for ax,pal,pln in zip(axs, palettes, planes):
        # ax.imshow(pal[pln])
        im = ax.imshow(15-pln, cmap=ListedColormap(pal[::-1] / 255.0))
        cbar = fig.colorbar(im, ax=ax, ticks=[],
                          fraction=0.1,    # Make the colorbar thinner
                          pad=0.01,         # Reduce padding between image and colorbar
                          shrink=0.6)       # Make it shorter than the image
        ax.axis('off')
    axs[-1].imshow(np.sum([pal[pln] for pal,pln in zip(palettes, planes)], axis=0))
    axs[-1].axis('off')
    plt.show()


def plt_tile_img(tiles):
    import matplotlib.pyplot as plt
    _nrows = tiles.shape[0]
    _ncols = tiles.shape[1]
    
    fig, ax = plt.subplots(nrows=_nrows, ncols=_ncols)
    
    for i in range(_nrows):
        for j in range(_ncols):
            ax[i, j].imshow(tiles[i, j])
            ax[i, j].set_axis_off()
    plt.show()


def main(image_path, output_path, show):
    n_planes = 4
    n_colors_per_palette = 15
    max_res = 128
    
    total_palette_colors = n_planes*n_colors_per_palette
    indexed_image, palette_colors = convert_and_show(
        image_path,
        total_palette_colors-2, # minus two to have it work even if shadows are enabled
        max_res,
        show=show
    )
    # add missing colours for it to be divisable by 15
    palette = np.concatenate([palette_colors, np.zeros(((n_planes*n_colors_per_palette) % len(palette_colors), 3), dtype=int)])
    
    # tilemap is words (2 bytes)
    # sprites are 8 bytes (sprite size can be up to 4 tiles wide/tall (Sprites consist of between 1 and 16 tiles) (64x64) per 8 bytes
    print(f"tiles: n_planes*{indexed_image.shape} / 2 (nibble) = {n_planes*indexed_image.shape[0]* indexed_image.shape[1] /2} bytes")
    print(f"tilemap: 2 bytes (word) * 1 tiles * {ceil(indexed_image.shape[0]/8)}*{ceil(indexed_image.shape[1]/8)} = {2*1*ceil(indexed_image.shape[0]/8) * ceil(indexed_image.shape[1]/8)} bytes")
    print(f"sprites: 2 overlapping * 8 bytes * {ceil(indexed_image.shape[0]/64)}*{ceil(indexed_image.shape[1]/64)} = {2*8*ceil(indexed_image.shape[0]/64) * ceil(indexed_image.shape[1]/64)} bytes")
    
    
    planes, palettes = split_palette(indexed_image, palette, n_planes, n_colors_per_palette)
    if show:
        show_planes(planes, palettes)
    
    tiled_images = [get_tile_images(img) for img in planes]
    # plt_tile_img(palettes[3][tiled_images[3]])
    
    file_bytes = convert_to_blob_bytes(tiled_images, palettes)
    
    with open(output_path, 'wb') as f:
        f.write(file_bytes)

IMAGES = {
    "lena": "https://upload.wikimedia.org/wikipedia/en/7/7d/Lenna_%28test_image%29.png",
    "baboon": "https://upload.wikimedia.org/wikipedia/commons/c/c1/Wikipedia-sipi-image-db-mandrill-4.2.03.png",
    "macaw": "https://upload.wikimedia.org/wikipedia/commons/b/bc/Parrot.red.macaw.1.arp.750pix.jpg"
}

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Convert images to blob. Must be a square image for now.')
    parser.add_argument('image', nargs='?', type=Path, default=None,
                        help=f'Path to the input image file (must be square) (or one of {", ".join(IMAGES.keys())})')
    parser.add_argument('-o', '--output', type=Path, default='out.simg',
                        help='Path for the output file (default: out.simg)')
    parser.add_argument('--show', action='store_true', help='Display the resulting image')
    parser.add_argument('--all', action='store_true', help='Get all images')
    args = parser.parse_args()
        
    if args.image and args.image.is_file():
        main(args.image, args.output, args.show)
        exit()
    elif args.image:
        raise ValueError(f"'{args.image}' is not a file.")
        
    from urllib.request import urlopen
    if args.all:
        for name, url in IMAGES.items():
            main(urlopen(url), f"{name}.simg", args.show)
    else:
        image = urlopen(IMAGES["lena"])
        main(image, args.output, args.show)
