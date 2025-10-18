#!/bin/bash

# 设置源文件夹、目标文件夹和COLMAP工作空间路径
SOURCE_DIR=""
TARGET_DIR=""
COLMAP_WORKSPACE="${TARGET_DIR}/workspace"
MERGED_MODEL_PATH="${COLMAP_WORKSPACE}/merged_model"

# 创建必要的工作目录
mkdir -p ${COLMAP_WORKSPACE}
mkdir -p ${MERGED_MODEL_PATH}

# 获取所有子文件夹的名字
SUBFOLDERS=($(ls -d ${SOURCE_DIR}/*/))  # 获取所有子文件夹路径

# 记录无法融合的子文件夹
FAILED_FOLDERS=()

# 对每个子文件夹进行 COLMAP 重建
for folder in "${SUBFOLDERS[@]}"; do
    # 获取子文件夹名
    FOLDER_NAME=$(basename "${folder}")

    # 为每个子文件夹创建独立的工作空间
    SUBFOLDER_WORKSPACE="${COLMAP_WORKSPACE}/${FOLDER_NAME}"
    mkdir -p ${SUBFOLDER_WORKSPACE}
    
    # 设置数据库路径和图像路径
    DATABASE_PATH="${SUBFOLDER_WORKSPACE}/database.db"
    IMAGES_PATH="${SUBFOLDER_WORKSPACE}/images"
    SPARSE_MODEL_PATH="${SUBFOLDER_WORKSPACE}/sparse"
    
    # 创建数据库并复制图像到工作目录
    mkdir -p ${IMAGES_PATH}
    cp ${folder}/* ${IMAGES_PATH}/

    # 删除现有的数据库（如果存在）
    if [ -f ${DATABASE_PATH} ]; then
        rm ${DATABASE_PATH}
    fi

    # 初始化 COLMAP 数据库
    echo "初始化 COLMAP 数据库（子文件夹：${FOLDER_NAME}）..."
    colmap database_creator --database_path ${DATABASE_PATH}

    # 特征提取（Feature Extraction）
    echo "开始进行特征提取（子文件夹：${FOLDER_NAME}）..."
    colmap feature_extractor --database_path ${DATABASE_PATH} --image_path ${IMAGES_PATH}

    # 特征匹配（Feature Matching）
    echo "开始进行特征匹配（子文件夹：${FOLDER_NAME}）..."
    colmap exhaustive_matcher --database_path ${DATABASE_PATH}

    # 稀疏重建（Sparse Reconstruction）
    echo "开始进行稀疏重建（子文件夹：${FOLDER_NAME}）..."
    mkdir -p ${SPARSE_MODEL_PATH}
    colmap mapper --database_path ${DATABASE_PATH} --image_path ${IMAGES_PATH} --output_path ${SPARSE_MODEL_PATH}

    # 检查稀疏重建的相机数量是否足够
    CAMERA_COUNT=$(ls ${SPARSE_MODEL_PATH}/0/*_camera.bin 2>/dev/null | wc -l)
    if [ ${CAMERA_COUNT} -lt 5 ]; then
        echo "警告：子文件夹 ${FOLDER_NAME} 的相机数量不足（${CAMERA_COUNT}），无法进行融合！"
        FAILED_FOLDERS+=("${FOLDER_NAME}")
    else
        echo "子文件夹 ${FOLDER_NAME} 重建完成，结果保存在 ${SPARSE_MODEL_PATH}"
    fi
done

# 如果有子文件夹无法进行融合，停止融合过程
if [ ${#FAILED_FOLDERS[@]} -gt 0 ]; then
    echo "以下子文件夹无法进行融合，因其相机数量不足："
    for folder in "${FAILED_FOLDERS[@]}"; do
        echo "- ${folder}"
    done
    echo "请检查以上子文件夹的数据重叠情况，确保它们有足够的重叠区域进行融合。"
    exit 1
fi

# 使用 colmap_merged 融合所有子文件夹的重建结果
echo "开始融合重建所有子文件夹结果..."
colmap_merged --workspace_path ${COLMAP_WORKSPACE} --output_path ${MERGED_MODEL_PATH}

echo "融合重建完成，结果保存在 ${MERGED_MODEL_PATH}"
