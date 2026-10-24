const notch = document.querySelector('#notch');
const shelf = document.querySelector('#shelf');
const hint = document.querySelector('#demo-hint');
const description = document.querySelector('#demo-description');
const attachment = document.querySelector('#attachment');
const files = document.querySelector('#files');
const count = document.querySelector('#item-count');
const status = document.querySelector('#shelf-status');
function setOpen(open) {
  shelf.hidden = !open;
  notch.setAttribute('aria-expanded', String(open));
  hint.textContent = open ? '再次点击刘海即可收起' : '点击顶部刘海，展开桌面文件';
}
notch.addEventListener('click', () => setOpen(shelf.hidden));
notch.addEventListener('keydown', event => { if (event.key === 'Escape') setOpen(false); });
for (const button of document.querySelectorAll('[data-scene]')) {
  button.addEventListener('click', () => {
    for (const item of document.querySelectorAll('[data-scene]')) {
      item.classList.toggle('selected', item === button);
      item.setAttribute('aria-pressed', String(item === button));
    }
    document.querySelector('#added-file')?.remove();
    count.textContent = '3 个项目 · 与桌面同步';
    status.textContent = '拖入存到桌面 · 拖出到其他应用';
    attachment.textContent = '把文件交给当前应用';
    attachment.classList.remove('attached');
    if (button.dataset.scene === 'reveal') {
      setOpen(true);
      description.textContent = '在应用里，靠近刘海即可展开，离开约 0.15 秒后隐藏。这里点击刘海即可体验示意。';
    } else if (button.dataset.scene === 'out') {
      setOpen(false);
      attachment.textContent = '✓ 项目提案.pdf · 已添加附件';
      attachment.classList.add('attached');
      hint.textContent = '文件交给当前应用，桌面原件仍保留';
      description.textContent = '拖出示意：将桌面文件交给支持拖放的应用。桌面原件会保留，无需来回切换窗口。';
    } else {
      setOpen(true);
      const row = document.createElement('div');
      row.className = 'file'; row.id = 'added-file';
      row.innerHTML = '<span class="file-icon pic">▧</span><div><strong>设计参考.png</strong><small>已复制到桌面</small></div><span class="file-arrow">✓</span>';
      files.append(row);
      count.textContent = '4 个项目 · 与桌面同步';
      status.textContent = '已存到桌面 · 1 个项目';
      hint.textContent = '松手之后，文件就到桌面了';
      description.textContent = '拖入示意：文件复制到桌面，列表自动更新。同名文件自动编号，不覆盖已有文件。';
    }
  });
}
