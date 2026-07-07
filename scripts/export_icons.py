import argparse
import io
import json
import os
import shutil
import subprocess
import tempfile
import inspect

from PIL import ImageChops
from PIL import Image
from psd_tools import PSDImage
from psd_tools.constants import BlendMode
from psd_tools.api.layers import Group, PixelLayer


def load_asset_image(image_path):
    """
    读取位图资源；如果资源是 SVG，先光栅化成 RGBA 位图。
    """
    _, ext = os.path.splitext(image_path)
    if ext.lower() == ".svg":
        try:
            import cairosvg

            png_bytes = cairosvg.svg2png(url=image_path)
            image = Image.open(io.BytesIO(png_bytes)).convert("RGBA")
            image.load()
            return image
        except Exception:
            converter = shutil.which("rsvg-convert") or shutil.which("magick")
            if not converter:
                raise RuntimeError("找不到可用的 SVG 转换器（cairosvg / rsvg-convert / magick）。")

            with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp_file:
                temp_png_path = tmp_file.name

            try:
                if os.path.basename(converter) == "magick":
                    command = [converter, image_path, temp_png_path]
                else:
                    command = [converter, "-f", "png", "-o", temp_png_path, image_path]

                subprocess.run(command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                image = Image.open(temp_png_path).convert("RGBA")
                image.load()
                return image
            finally:
                if os.path.exists(temp_png_path):
                    os.remove(temp_png_path)
    return Image.open(image_path).convert("RGBA")


def parse_color(color_str):
    if ":" in color_str:
        color_data = color_str.split(":", 1)[1]
    else:
        color_data = color_str

    r, g, b, a = [float(v) for v in color_data.split(",")]
    return (int(r * 255), int(g * 255), int(b * 255), int(a * 255))


def resolve_specialized_value(specializations, appearance):
    if not specializations:
        return None

    default_value = None
    for spec in specializations:
        spec_appearance = spec.get("appearance")
        if spec_appearance == appearance:
            return spec.get("value")
        if spec_appearance is None and default_value is None:
            default_value = spec.get("value")

    return default_value


def resolve_opacity(node, appearance):
    specialized = resolve_specialized_value(node.get("opacity-specializations"), appearance)
    value = specialized if specialized is not None else node.get("opacity", 1.0)
    return max(0.0, min(1.0, float(value)))


def resolve_fill(node, appearance):
    specialized = resolve_specialized_value(node.get("fill-specializations"), appearance)
    if specialized is not None:
        return specialized
    return node.get("fill")


def resolve_blend_mode(node, appearance):
    specialized = resolve_specialized_value(node.get("blend-mode-specializations"), appearance)
    if specialized is not None:
        return specialized
    return node.get("blend-mode")


def resolve_visibility(node):
    return not bool(node.get("hidden", False))


def resolve_position(group_position, layer_position):
    group_position = group_position or {}
    layer_position = layer_position or {}

    group_scale = float(group_position.get("scale", 1.0))
    layer_scale = float(layer_position.get("scale", 1.0))

    group_translation = group_position.get("translation-in-points", [0, 0])
    layer_translation = layer_position.get("translation-in-points", [0, 0])

    group_x, group_y = group_translation[0], group_translation[1]
    layer_x, layer_y = layer_translation[0], layer_translation[1]

    return {
        "scale": group_scale * layer_scale,
        "translation_x": float(group_x) + float(layer_x) * group_scale,
        "translation_y": float(group_y) + float(layer_y) * group_scale,
    }


def apply_solid_fill(layer_img, fill_value):
    if not isinstance(fill_value, dict) or "solid" not in fill_value:
        return layer_img

    solid = Image.new("RGBA", layer_img.size, parse_color(fill_value["solid"]))
    solid.putalpha(layer_img.getchannel("A"))
    return solid


def apply_opacity(layer_img, opacity):
    if opacity >= 0.999:
        return layer_img

    alpha = layer_img.getchannel("A").point(lambda value: int(value * opacity))
    result = layer_img.copy()
    result.putalpha(alpha)
    return result


def apply_blend_mode(base_image, layer_image, blend_mode):
    if blend_mode == "lighten":
        return ImageChops.lighter(base_image, layer_image)
    return Image.alpha_composite(base_image, layer_image)


def safe_set_blend_mode(layer, blend_mode):
    if not blend_mode:
        return

    try:
        normalized = blend_mode.replace("-", "_").replace(" ", "_").upper()
        if normalized in BlendMode.__members__:
            layer.blend_mode = BlendMode[normalized]
        else:
            layer.blend_mode = blend_mode
    except Exception:
        print(f"⚠️ 不支持的混合模式: {blend_mode}，已忽略。")


PIXEL_LAYER_FROMPIL_PARAMS = set(inspect.signature(PixelLayer.frompil).parameters.keys())


def create_pixel_layer(group, psd, layer):
    common_kwargs = {
        "top": layer["offset_y"],
        "left": layer["offset_x"],
    }

    if "parent" in PIXEL_LAYER_FROMPIL_PARAMS:
        return PixelLayer.frompil(
            layer["image"],
            parent=group,
            name=layer["name"],
            **common_kwargs,
        )

    pixel_layer = PixelLayer.frompil(
        layer["image"],
        psd_file=psd,
        layer_name=layer["name"],
        **common_kwargs,
    )
    group.append(pixel_layer)
    return pixel_layer


def prepare_layer(layer, assets_dir, base_size, group_position, appearance):
    image_name = layer.get("image-name")
    if not image_name:
        return None

    image_path = os.path.join(assets_dir, image_name)
    if not os.path.exists(image_path):
        print(f"⚠️ 找不到图片: {image_name}，跳过。")
        return None

    layer_img = load_asset_image(image_path)
    layer_img = apply_solid_fill(layer_img, resolve_fill(layer, appearance))

    resolved_position = resolve_position(group_position, layer.get("position", {}))
    scale = resolved_position["scale"]
    trans_x = resolved_position["translation_x"]
    trans_y = resolved_position["translation_y"]

    if scale != 1.0:
        new_w = int(layer_img.width * scale)
        new_h = int(layer_img.height * scale)
        layer_img = layer_img.resize((new_w, new_h), Image.Resampling.LANCZOS)

    offset_x = (base_size[0] - layer_img.width) // 2 + int(trans_x)
    offset_y = (base_size[1] - layer_img.height) // 2 - int(trans_y)

    return {
        "name": layer.get("name", image_name),
        "image": layer_img,
        "offset_x": offset_x,
        "offset_y": offset_y,
        "opacity": resolve_opacity(layer, appearance),
        "visible": resolve_visibility(layer),
        "blend_mode": resolve_blend_mode(layer, appearance),
    }


def collect_render_groups(config, assets_dir, base_size, appearance):
    """
    按当前脚本的实际绘制顺序收集图层，确保 PNG / PSD 视觉一致。
    """
    render_groups = []

    for group in reversed(config.get("groups", [])):
        prepared_layers = []
        group_position = group.get("position")
        for layer in reversed(group.get("layers", [])):
            prepared = prepare_layer(layer, assets_dir, base_size, group_position, appearance)
            if prepared is not None:
                prepared_layers.append(prepared)
                print(f"✅ 已解析图层: {prepared['name']}")

        if prepared_layers:
            render_groups.append(
                {
                    "name": group.get("name", "Group"),
                    "layers": prepared_layers,
                    "opacity": resolve_opacity(group, appearance),
                    "visible": resolve_visibility(group),
                    "blend_mode": resolve_blend_mode(group, appearance),
                }
            )

    return render_groups


def save_flattened_icon(render_groups, output_path, base_size):
    canvas = Image.new("RGBA", base_size, (0, 0, 0, 0))

    for group in render_groups:
        if not group["visible"]:
            continue

        group_canvas = Image.new("RGBA", base_size, (0, 0, 0, 0))
        for layer in group["layers"]:
            if not layer["visible"]:
                continue

            temp_layer = Image.new("RGBA", base_size, (0, 0, 0, 0))
            temp_layer.paste(
                apply_opacity(layer["image"], layer["opacity"]),
                (layer["offset_x"], layer["offset_y"]),
            )
            group_canvas = apply_blend_mode(group_canvas, temp_layer, layer["blend_mode"])

        group_canvas = apply_opacity(group_canvas, group["opacity"])
        canvas = apply_blend_mode(canvas, group_canvas, group["blend_mode"])

    canvas.save(output_path)


def save_layered_psd(render_groups, output_path, base_size):
    psd = PSDImage.new("RGBA", base_size, color=0)

    for group_data in render_groups:
        group = Group.new(parent=psd, name=group_data["name"])
        group.opacity = round(group_data["opacity"] * 255)
        group.visible = group_data["visible"]
        safe_set_blend_mode(group, group_data["blend_mode"])

        for layer in group_data["layers"]:
            pixel_layer = create_pixel_layer(group, psd, layer)
            pixel_layer.opacity = round(layer["opacity"] * 255)
            pixel_layer.visible = layer["visible"]
            safe_set_blend_mode(pixel_layer, layer["blend_mode"])

    psd.save(output_path)

def generate_icon_from_bundle(icon_bundle_path, output_path, base_size=(1024, 1024), appearance="default"):
    """
    读取苹果的 .icon 包文件夹。
    输出 .psd 时保留分层；其它格式则导出扁平位图。
    """
    json_path = os.path.join(icon_bundle_path, "icon.json")
    assets_dir = os.path.join(icon_bundle_path, "Assets")
    
    if not os.path.isdir(icon_bundle_path):
        print(f"❌ 错误: 找不到图标包 {icon_bundle_path}")
        return
    if not os.path.exists(json_path):
        print(f"❌ 错误: 在包内找不到 {json_path}")
        return

    print(f"📂 正在解析图标包: {icon_bundle_path}")

    with open(json_path, 'r', encoding='utf-8') as f:
        config = json.load(f)

    render_groups = collect_render_groups(config, assets_dir, base_size, appearance)

    if output_path.lower().endswith(".psd"):
        save_layered_psd(render_groups, output_path, base_size)
        print(f"\n🎉 搞定！分层 PSD 已保存至: {output_path}")
    else:
        save_flattened_icon(render_groups, output_path, base_size)
        print(f"\n🎉 搞定！合成图标已保存至: {output_path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="从苹果 .icon 文件包导出图标（支持 PSD）")
    parser.add_argument("input", help="输入的 .icon 文件夹路径")
    parser.add_argument("-o", "--output", default="output.psd", help="输出文件路径 (默认: output.psd)")
    parser.add_argument(
        "--appearance",
        choices=["default", "dark", "tinted"],
        default="default",
        help="选择要导出的外观分支 (默认: default)",
    )
    
    args = parser.parse_args()
    generate_icon_from_bundle(args.input, args.output, appearance=args.appearance)
