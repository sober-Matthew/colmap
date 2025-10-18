#!/bin/bash

# 设置源文件夹、目标文件夹和COLMAP工作空间路径
SOURCE_DIR=""
TARGET_DIR=""
COLMAP_WORKSPACE=""
DATABASE_PATH="${COLMAP_WORKSPACE}/database.db"
IMAGES_PATH="${COLMAP_WORKSPACE}/images"
SPARSE_MODEL_PATH="${COLMAP_WORKSPACE}/sparse"

# 创建目标文件夹和其他必要的文件夹
mkdir -p ${TARGET_DIR}
mkdir -p ${IMAGES_PATH}
mkdir -p ${SPARSE_MODEL_PATH}

# 获取所有子文件夹的名字
SUBFOLDERS=($(ls -d ${SOURCE_DIR}/*/))  # 获取所有子文件夹路径

# 计算每个子文件夹内的照片总数
FILES_PER_SUBFOLDER=999
TOTAL_FILES=0
for folder in "${SUBFOLDERS[@]}"; do
    TOTAL_FILES=$((TOTAL_FILES + $(ls ${folder} | wc -l)))
done

# 计算采样步长（每隔多少张采样一次）
STEP=$((TOTAL_FILES / 1200))

# 进行间隔采样，选取少于1200张图片并复制到目标文件夹，避免重名
echo "开始采样并保存少于1200张照片..."
CURRENT_FILE_COUNT=0
SAVED_COUNT=0
NEW_NAME_INDEX=1  # 用于重命名的新的文件名索引

for folder in "${SUBFOLDERS[@]}"; do
    IMAGE_FILES=($(ls ${folder} | sort))  # 获取子文件夹中的所有图片并排序

    for img_file in "${IMAGE_FILES[@]}"; do
        if [ $((CURRENT_FILE_COUNT % STEP)) -eq 0 ] && [ ${SAVED_COUNT} -lt 1200 ]; then
            # 创建新的唯一文件名
            NEW_FILE_NAME="IMG_${NEW_NAME_INDEX}.JPG"
            cp "${folder}/${img_file}" "${TARGET_DIR}/${NEW_FILE_NAME}"
            NEW_NAME_INDEX=$((NEW_NAME_INDEX + 1))
            SAVED_COUNT=$((SAVED_COUNT + 1))
        fi
        CURRENT_FILE_COUNT=$((CURRENT_FILE_COUNT + 1))
    done
done

echo "成功采样并保存到 ${TARGET_DIR}，共保存 ${SAVED_COUNT} 张照片"

# 删除现有的数据库（如果存在）
if [ -f ${DATABASE_PATH} ]; then
    rm ${DATABASE_PATH}
fi

# 创建 COLMAP 数据库
echo "初始化 COLMAP 数据库..."
colmap database_creator --database_path ${DATABASE_PATH}

# 将采样的照片复制到 COLMAP 项目的 images 文件夹
echo "复制照片到 COLMAP 图像文件夹..."
cp ${TARGET_DIR}/* ${IMAGES_PATH}/

# 特征提取（Feature Extraction）
echo "开始进行特征提取..."
colmap feature_extractor --database_path ${DATABASE_PATH} --image_path ${IMAGES_PATH}

# 特征匹配（Feature Matching）
echo "开始进行特征匹配..."
colmap exhaustive_matcher --database_path ${DATABASE_PATH}

# 稀疏重建（Sparse Reconstruction）
echo "开始进行稀疏重建..."
colmap mapper --database_path ${DATABASE_PATH} --image_path ${IMAGES_PATH} --output_path ${SPARSE_MODEL_PATH}

echo "COLMAP 重建完成，结果保存在 ${SPARSE_MODEL_PATH}"
