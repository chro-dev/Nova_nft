const fs = require('fs');
const path = require('path');

const folderPath = './metadata'; // 替换为您的 metadata 文件夹路径

fs.readdir(folderPath, (err, files) => {
  if (err) {
    console.error('读取文件夹失败:', err);
    return;
  }

  files.forEach(file => {
    const filePath = path.join(folderPath, file);
    const fileExt = path.extname(file);

    if (fileExt) {
      const newFileName = path.join(folderPath, path.basename(file, fileExt));
      fs.rename(filePath, newFileName, err => {
        if (err) {
          console.error(`重命名文件 ${file} 失败:`, err);
        } else {
          console.log(`文件 ${file} 已重命名为 ${path.basename(newFileName)}`);
        }
      });
    }
  });
});