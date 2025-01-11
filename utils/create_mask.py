import argparse
import pathlib

import numpy as np
from PIL import Image

DARK_THRESHOLD = 250
LIGHT_THRESHOLD = 30

# base_game
# DARK_THRESHOLD = 250
# LIGHT_THRESHOLD = 30

# 100
# DARK_THRESHOLD = 245
# LIGHT_THRESHOLD = 15


def save_image(img_array, mode):
    output_image = Image.fromarray(img_array)
    output_image.save(pathlib.Path(__file__).parent / "masks" / f"{mode}.png")


def create_mask(input_path, mode):
    # convert to grayscale
    image = Image.open(input_path).convert("L")
    image_data = np.array(image)

    # select pixels based on threshold
    mask = image_data < LIGHT_THRESHOLD
    bg_color = 255
    if mode == "dark":
        mask = image_data > DARK_THRESHOLD
        bg_color = 0

    # output mask
    output_img = np.zeros_like(image_data)
    output_img[mask] = image_data[mask]
    # all non selected pixels are set to the background color
    output_img[~mask] = bg_color

    # inverse mask
    # other_mode = "light" if mode == "dark" else "dark"
    # inverse_img = 255 - output_img

    save_image(output_img, mode)
    # save_image(inverse_img, other_mode)


def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "mode",
        choices=["light", "dark"],
        help="Brightness of the input image",
    )
    parser.add_argument("input", help="Path to the input image")
    return parser.parse_args()


if __name__ == "__main__":
    args = get_args()
    create_mask(args.input, args.mode)
