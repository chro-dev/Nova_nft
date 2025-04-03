const fs = require('fs');
const path = require('path');

// 定义元数据目录
const metadataDir = path.join(__dirname, 'metadata');

// 如果目录不存在，则创建
if (!fs.existsSync(metadataDir)) {
  fs.mkdirSync(metadataDir);
}

// 定义图片 URL（假设图片已上传到 GitHub）
const imageUrl = 'https://raw.githubusercontent.com/chro-dev/Nova_nft/main/nova.jpg';

// 生成 JSON 文件（例如生成 10 个，您可以修改数量）
const totalNFTs = 1493; // 可改为您需要的数量，例如 1493
for (let i = 1; i <= totalNFTs; i++) {
  const metadata = {
    name: `NOVA NFT #${i}`,
    description: 'A unique NOVA NFT',
    image: imageUrl
  };
  const filePath = path.join(metadataDir, `${i}.json`);
  fs.writeFileSync(filePath, JSON.stringify(metadata, null, 2));
  console.log(`已生成文件：${filePath}`);
}

console.log('所有元数据文件生成完成！');