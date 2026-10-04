"""Fine-tunes a small ImageNet-pretrained CNN into a bark/trunk species
classifier for the 18 classes in labels.json: the 17 species this app's
permit dropdown supports (7 original + 10 Central Luzon natives), and 1
"Unknown_Noise" background/reject class. Exports the result to ONNX for
serving by app.py (see README.md for the full data -> train -> export ->
deploy flow).

Training on the Unknown_Noise class (even though app.py only ever
*reports* predictions for the 17 real species — see README.md section 0)
teaches the model to recognize "this is not any known species" instead of
being forced to force-fit every bark photo into one of the 17 buckets.
That makes the 17 reported predictions more trustworthy, not just broader.

This is intentionally a *transfer-learning* script, not a from-scratch CNN:
MobileNetV3-Small/ResNet18 already know generic visual features from
ImageNet, so only the last layer(s) need real training on your bark photos.
On a free Colab GPU this typically finishes in well under an hour for a
dataset of a few hundred to a few thousand images per species.

Usage:
    python train.py --data-dir ./data --arch mobilenet_v3_small \
        --epochs 15 --out bark_classifier.onnx

Expected --data-dir layout (torchvision ImageFolder convention; folder
names must match labels.json exactly):
    data/
      Mahogany/*.jpg
      Mango/*.jpg
      Gmelina/*.jpg
      Acacia/*.jpg
      Narra/*.jpg
      Ipil_Ipil/*.jpg
      Coconut/*.jpg
      White_Lauan/*.jpg
      Guijo/*.jpg
      Apitong/*.jpg
      Red_Lauan/*.jpg
      Mayapis/*.jpg
      Tindalo/*.jpg
      Bolongeta/*.jpg
      Malaikmo/*.jpg
      Bayanti/*.jpg
      Malatanglin/*.jpg
      Unknown_Noise/*.jpg   <- leaves, random objects, blurry shots, other
                               tree species' bark, etc. Without enough
                               varied images here the model will still try
                               to confidently guess one of the 17 real
                               classes for completely unrelated photos.

See README.md for where to source bark photos for each species.
"""
import argparse
import json
from pathlib import Path

import torch
from torch import nn
from torch.utils.data import DataLoader, random_split
from torchvision import datasets, models, transforms

IMAGENET_MEAN = [0.485, 0.456, 0.406]
IMAGENET_STD = [0.229, 0.224, 0.225]
IMAGE_SIZE = 224


def build_model(arch: str, num_classes: int) -> nn.Module:
    if arch == "mobilenet_v3_small":
        model = models.mobilenet_v3_small(weights=models.MobileNet_V3_Small_Weights.IMAGENET1K_V1)
        in_features = model.classifier[-1].in_features
        model.classifier[-1] = nn.Linear(in_features, num_classes)
        return model
    if arch == "resnet18":
        model = models.resnet18(weights=models.ResNet18_Weights.IMAGENET1K_V1)
        model.fc = nn.Linear(model.fc.in_features, num_classes)
        return model
    raise ValueError(f"Unsupported --arch '{arch}'. Use mobilenet_v3_small or resnet18.")


def build_transforms():
    train_transform = transforms.Compose([
        transforms.Resize(256),
        transforms.RandomResizedCrop(IMAGE_SIZE, scale=(0.7, 1.0)),
        transforms.RandomHorizontalFlip(),
        # Bark photos vary a lot in lighting/weather; emphasize color/lighting
        # robustness over the shape-oriented augmentations leaf classifiers use.
        transforms.ColorJitter(brightness=0.3, contrast=0.3, saturation=0.2),
        transforms.ToTensor(),
        transforms.Normalize(IMAGENET_MEAN, IMAGENET_STD),
    ])
    eval_transform = transforms.Compose([
        transforms.Resize(256),
        transforms.CenterCrop(IMAGE_SIZE),
        transforms.ToTensor(),
        transforms.Normalize(IMAGENET_MEAN, IMAGENET_STD),
    ])
    return train_transform, eval_transform


def train(args: argparse.Namespace) -> None:
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Using device: {device}")

    train_transform, eval_transform = build_transforms()
    full_dataset = datasets.ImageFolder(args.data_dir, transform=train_transform)
    class_names = full_dataset.classes
    print(f"Found {len(class_names)} classes: {class_names}")
    print(f"Found {len(full_dataset)} images total.")

    expected = json.loads(Path(args.labels_json).read_text())["labels"]
    missing = [label for label in expected if label not in class_names]
    extra = [label for label in class_names if label not in expected]
    if missing:
        print(f"WARNING: no training images found for: {missing}. "
              "The exported model will not be able to recognize these species.")
    if extra:
        print(f"WARNING: unexpected class folders not in labels.json: {extra}. "
              "Rename/remove them or add them to labels.json and the app's dropdown.")

    val_size = max(1, int(len(full_dataset) * args.val_split))
    train_size = len(full_dataset) - val_size
    train_subset, val_subset = random_split(
        full_dataset, [train_size, val_size],
        generator=torch.Generator().manual_seed(args.seed),
    )
    # The validation subset must use eval-time (non-augmented) transforms.
    val_subset.dataset = datasets.ImageFolder(args.data_dir, transform=eval_transform)

    train_loader = DataLoader(train_subset, batch_size=args.batch_size, shuffle=True, num_workers=args.workers)
    val_loader = DataLoader(val_subset, batch_size=args.batch_size, shuffle=False, num_workers=args.workers)

    model = build_model(args.arch, len(class_names)).to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=args.lr)
    criterion = nn.CrossEntropyLoss()

    best_val_acc = 0.0
    for epoch in range(1, args.epochs + 1):
        model.train()
        running_loss = 0.0
        for images, targets in train_loader:
            images, targets = images.to(device), targets.to(device)
            optimizer.zero_grad()
            outputs = model(images)
            loss = criterion(outputs, targets)
            loss.backward()
            optimizer.step()
            running_loss += loss.item() * images.size(0)

        model.eval()
        correct = 0
        total = 0
        with torch.no_grad():
            for images, targets in val_loader:
                images, targets = images.to(device), targets.to(device)
                outputs = model(images)
                correct += (outputs.argmax(dim=1) == targets).sum().item()
                total += targets.size(0)
        val_acc = correct / max(1, total)
        best_val_acc = max(best_val_acc, val_acc)
        print(f"Epoch {epoch}/{args.epochs} - train_loss={running_loss / len(train_subset):.4f} "
              f"val_acc={val_acc:.4f}")

    print(f"Best validation accuracy: {best_val_acc:.4f}")
    if best_val_acc < 0.7:
        print("WARNING: validation accuracy is low. Collect more images per "
              "species (aim for 200+ each) before deploying this model.")

    export_onnx(model, class_names, args.out, device)


def export_onnx(model: nn.Module, class_names: list[str], out_path: str, device: torch.device) -> None:
    model.eval()
    dummy_input = torch.randn(1, 3, IMAGE_SIZE, IMAGE_SIZE, device=device)
    torch.onnx.export(
        model, dummy_input, out_path,
        input_names=["input"], output_names=["logits"],
        dynamic_axes={"input": {0: "batch"}, "logits": {0: "batch"}},
        opset_version=17,
    )
    labels_path = Path(out_path).with_suffix(".labels.json")
    labels_path.write_text(json.dumps(class_names, indent=2))
    print(f"Exported model to {out_path}")
    print(f"Exported class order to {labels_path} (app.py needs this file alongside the model)")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-dir", default="./data", help="ImageFolder-style dataset root.")
    parser.add_argument("--labels-json", default="./labels.json",
                         help="Canonical dropdown labels this model must cover.")
    parser.add_argument("--arch", default="mobilenet_v3_small",
                         choices=["mobilenet_v3_small", "resnet18"])
    parser.add_argument("--epochs", type=int, default=15)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--lr", type=float, default=1e-3)
    parser.add_argument("--val-split", type=float, default=0.2)
    parser.add_argument("--workers", type=int, default=2)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--out", default="./bark_classifier.onnx")
    return parser.parse_args()


if __name__ == "__main__":
    train(parse_args())
