#!/usr/bin/env bash
set -euo pipefail

if ! command -v colmap >/dev/null 2>&1; then
  echo "[ERROR] COLMAP not found in PATH. Please ensure 'colmap' is installed and on PATH." >&2
  exit 1
fi

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <parent_dir_with_6_subfolders> <workdir>"
  exit 1
fi

PARENT_DIR="$(realpath "$1")"
WORKDIR="$(realpath "$2")"

MERGED_DIR="${WORKDIR}/images_merged"
DB_PATH="${WORKDIR}/database.db"
SPARSE_DIR="${WORKDIR}/sparse"

echo "Parent dir : ${PARENT_DIR}"
echo "Workdir    : ${WORKDIR}"
echo "Merged dir : ${MERGED_DIR}"
echo "Database   : ${DB_PATH}"
echo "Sparse out : ${SPARSE_DIR}"
echo

mkdir -p "${MERGED_DIR}"
mkdir -p "${SPARSE_DIR}"

# 清理旧数据库（如存在） | Clean old database if exists
if [[ -f "${DB_PATH}" ]]; then
  echo "[Info] Removing existing database.db"
  rm -f "${DB_PATH}"
fi

echo "[Step 1/4] Merging images from subfolders into ${MERGED_DIR}"
shopt -s nullglob
num_copied=0
while IFS= read -r -d '' subdir; do
  bn="$(basename "$subdir")"
  for img in "${subdir}"/*.{jpg,JPG,jpeg,JPEG,png,PNG,tif,TIF,tiff,TIFF}; do
    base="$(basename "$img")"
    # 以子目录名作为前缀避免重名 | prefix with subfolder name to avoid collisions
    out="${MERGED_DIR}/${bn}__${base}"
    # 若已存在同名文件，则在末尾追加计数 | append counter if exists
    if [[ -e "$out" ]]; then
      idx=1
      ext="${out##*.}"
      name="${out%.*}"
      while [[ -e "${name}_${idx}.${ext}" ]]; do
        ((idx++))
      done
      out="${name}_${idx}.${ext}"
    fi
    cp -n "$img" "$out"
    ((num_copied++)) || true
  done
done < <(find "${PARENT_DIR}" -mindepth 1 -maxdepth 1 -type d -print0)

if [[ $num_copied -eq 0 ]]; then
  echo "[ERROR] No images found to merge. Please check your folders."
  exit 1
fi

echo "[Info] Copied ${num_copied} images."
echo

echo "[Step 2/4] Feature extraction"
# 常用参数：按需修改，如相机模型、单相机、GPU开关等
# Common toggles: camera model, single_camera, GPU usage, etc.
colmap feature_extractor \
  --database_path "${DB_PATH}" \
  --image_path "${MERGED_DIR}" \
  --ImageReader.camera_model PINHOLE \
  --SiftExtraction.use_gpu 1

echo
echo "[Step 3/4] Feature matching (exhaustive)"

# For ordered sequences, consider colmap sequential_matcher
colmap exhaustive_matcher \
  --database_path "${DB_PATH}" \
  --SiftMatching.use_gpu 1

echo
echo "[Step 4/4] Mapping (sparse reconstruction)"
# 运行重建；COLMAP 会在 sparse/ 下生成子目录 0,1,...
colmap mapper \
  --database_path "${DB_PATH}" \
  --image_path "${MERGED_DIR}" \
  --output_path "${SPARSE_DIR}" \
  --Mapper.ba_global_max_num_iterations 50

# 找到第一个模型子目录（通常为 0），并导出为 TXT（cameras.txt 等）
MODEL_DIR=""
if [[ -d "${SPARSE_DIR}/0" ]]; then
  MODEL_DIR="${SPARSE_DIR}/0"
else
  # 若不是 0，则取第一个非空目录
  first_model="$(find "${SPARSE_DIR}" -mindepth 1 -maxdepth 1 -type d | head -n1 || true)"
  if [[ -n "${first_model}" ]]; then
    MODEL_DIR="${first_model}"
  fi
fi

if [[ -z "${MODEL_DIR}" ]]; then
  echo "[ERROR] No sparse model directory produced. Please check COLMAP logs."
  exit 1
fi

echo "[Info] Converting model at ${MODEL_DIR} to TXT format in ${SPARSE_DIR}"
colmap model_converter \
  --input_path "${MODEL_DIR}" \
  --output_path "${SPARSE_DIR}" \
  --output_type TXT

echo
echo "===== Done ====="
echo "Merged images : ${MERGED_DIR}"
echo "Database      : ${DB_PATH}"
echo "Sparse (TXT)  : ${SPARSE_DIR}/cameras.txt"
echo "                ${SPARSE_DIR}/images.txt"
echo "                ${SPARSE_DIR}/points3D.txt"
