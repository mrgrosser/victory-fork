"""Compare two local captures from the fixed prison-window camera. Requires Pillow."""
import argparse
import json
from statistics import correlation, mean

from PIL import Image


# Regions in the 760 x 427 prison reference thumbnail. Resize both inputs to
# the same grid before sampling. Inspect crops again after a camera change.
REGIONS = {
    "left_wall": (8, 171, 63, 260),
    "right_bunk": (578, 114, 649, 182),
    "sunlit_yard": (320, 105, 471, 266),
}


def compare(reference_path, candidate_path):
    with Image.open(reference_path) as image:
        reference = image.convert("L").resize((760, 427), Image.Resampling.BILINEAR)
    with Image.open(candidate_path) as image:
        candidate = image.convert("L").resize(reference.size, Image.Resampling.BILINEAR)
    grids = [image.resize((80, 45), Image.Resampling.BILINEAR).crop((2, 2, 77, 44)).tobytes()
             for image in (reference, candidate)]
    # A uniformly dark loading frame has no spatial correlation.
    spatial = None if any(min(g) == max(g) for g in grids) else round(correlation(*grids), 4)
    values = {}
    for name, rect in REGIONS.items():
        before, after = [image.crop(rect).tobytes() for image in (reference, candidate)]
        values[name] = {
            "reference_gray": round(mean(before), 2),
            "candidate_gray": round(mean(after), 2),
            "mean_absolute_difference": round(mean(abs(a - b) for a, b in zip(before, after)), 2),
        }
    return {"spatial_correlation": spatial, "regions": values}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reference")
    parser.add_argument("candidate")
    args = parser.parse_args()
    print(json.dumps(compare(args.reference, args.candidate), indent=2))
