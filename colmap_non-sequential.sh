#!/bin/bash

# 设置COLMAP的工作路径和相关路径
COLMAP_WORKSPACE="/data02/zhangwei/colmap/workspace"
DATABASE_PATH="${COLMAP_WORKSPACE}/database.db"
IMAGES_PATH="${COLMAP_WORKSPACE}/images"
SPARSE_MODEL_PATH="${COLMAP_WORKSPACE}/sparse"
TARGET_DIR="${COLMAP_WORKSPACE}/images_selected"

# 创建必要的文件夹
mkdir -p ${TARGET_DIR}

# 1. 初始化COLMAP数据库
echo "初始化 COLMAP 数据库..."
colmap database_creator --database_path ${DATABASE_PATH}

# 2. 提取特征
echo "提取图像特征..."
colmap feature_extractor \
    --database_path ${DATABASE_PATH} \
    --image_path ${IMAGES_PATH} \
    --SiftExtraction.estimate_affine_shape=true

# 3. 使用 vocab_tree_matcher 限定候选对
echo "使用 vocab_tree_matcher 限定候选对..."
colmap vocab_tree_matcher \
    --database_path ${DATABASE_PATH} \
    --image_path ${IMAGES_PATH} \
    --vocab_tree_path /path/to/vocab_tree.bin \
    --match_type 2  # 2 表示使用视觉词典进行匹配

# 4. 进行空间约束匹配
echo "使用 spatial_matcher 限定候选对..."
colmap spatial_matcher \
    --database_path ${DATABASE_PATH} \
    --image_path ${IMAGES_PATH} \
    --max_distance 0.01 \
    --max_angle 30  # 调整最大距离和角度阈值以限制匹配

# 5. 执行几何验证
echo "进行几何验证..."
colmap geometric_verifier \
    --database_path ${DATABASE_PATH} \
    --image_path ${IMAGES_PATH} \
    --min_inlier_ratio 0.2 \
    --max_error 2.0

# 6. 生成稀疏模型
echo "生成稀疏模型..."
colmap mapper \
    --database_path ${DATABASE_PATH} \
    --image_path ${IMAGES_PATH} \
    --output_path ${SPARSE_MODEL_PATH}

# 7. 将匹配结果复制到目标文件夹
echo "将匹配结果复制到目标文件夹..."
cp ${IMAGES_PATH}/* ${TARGET_DIR}/

echo "完成所有操作！"
