const EntryColumnFlow = {
  mounted() {
    console.log('[EntryColumnFlow] mounted', this.el.id);
    this.el.__liveHook = this;
    this.el.dataset.mounted = 'true';
    this.lastWidth = window.innerWidth;
    this.pagesCreated = false;
    this.measureAndCreatePages();
    
    this.resizeObserver = new ResizeObserver(() => {
      if (Math.abs(window.innerWidth - this.lastWidth) > 50) {
        this.lastWidth = window.innerWidth;
        this.pagesCreated = false;
        this.measureAndCreatePages();
      }
    });
    this.resizeObserver.observe(this.el);
  },

  updated() {
  },

  destroyed() {
    console.log('[EntryColumnFlow] destroyed', this.el?.id);
    if (this.resizeObserver) {
      this.resizeObserver.disconnect();
    }
    const wrapper = this.el.closest('.book-entry-flow-wrapper');
    if (wrapper) {
      const entryId = this.el.dataset.entryId;
      const pages = wrapper.querySelectorAll('.book-column-page[data-entry-id="' + entryId + '"]');
      console.log('[EntryColumnFlow] Removing', pages.length, 'pages for', entryId);
      pages.forEach(p => p.remove());
    }
  },

  measureAndCreatePages() {
    console.log('[EntryColumnFlow] measureAndCreatePages called, pagesCreated:', this.pagesCreated);
    if (this.pagesCreated) return;
    
    const container = this.el;
    const wrapper = container.closest('.book-entry-flow-wrapper');
    if (!wrapper) return;

    const header = container.querySelector('[data-header="true"]');
    const body = container.querySelector('[data-body="true"]');
    if (!body) return;

    const isMobile = window.innerWidth < 768;
    const pageWidth = isMobile ? window.innerWidth : window.innerWidth / 2;
    const paddingX = isMobile ? 32 : (window.innerWidth >= 1024 ? 160 : 128);
    const paddingTop = 72;
    const paddingBottom = 80;
    const contentWidth = pageWidth - paddingX;
    const contentHeight = window.innerHeight - paddingTop - paddingBottom;

    const entryId = container.dataset.entryId;
    const existingPages = wrapper.querySelectorAll('.book-column-page[data-entry-id="' + entryId + '"]');
    existingPages.forEach(p => p.remove());

    const headerClone = header ? header.cloneNode(true) : null;
    const bodyClone = body.cloneNode(true);

    const measureDiv = document.createElement('div');
    measureDiv.style.cssText = `
      position: absolute;
      visibility: hidden;
      width: ${contentWidth}px;
      height: auto;
      overflow: visible;
    `;
    if (headerClone) measureDiv.appendChild(headerClone);
    measureDiv.appendChild(bodyClone);
    document.body.appendChild(measureDiv);

    const totalHeight = measureDiv.scrollHeight;
    document.body.removeChild(measureDiv);

    const headerHeight = header ? header.offsetHeight : 0;
    const firstPageBodyHeight = contentHeight - headerHeight - 16;
    const subsequentPageBodyHeight = contentHeight - 40;

    let pages = [];
    const bookId = body.dataset.bookId;

    const fullHtml = body.innerHTML;
    const textContent = body.textContent || '';
    const totalChars = textContent.length;
    
    if (totalHeight <= contentHeight) {
      pages.push({
        headerHtml: header ? header.outerHTML : '',
        bodyHtml: fullHtml,
        isFirst: true,
        isLast: true
      });
    } else {
      let remainingHtml = fullHtml;
      let pageIndex = 0;
      
      while (remainingHtml.trim().length > 0) {
        const isFirst = pageIndex === 0;
        const availableHeight = isFirst ? firstPageBodyHeight : subsequentPageBodyHeight;
        
        const { usedHtml, leftoverHtml } = this.splitHtmlToFit(
          remainingHtml, 
          contentWidth, 
          availableHeight
        );
        
        if (usedHtml.trim().length === 0) break;
        
        pages.push({
          headerHtml: isFirst && header ? header.outerHTML : '',
          bodyHtml: usedHtml,
          isFirst: isFirst,
          isLast: leftoverHtml.trim().length === 0
        });
        
        remainingHtml = leftoverHtml;
        pageIndex++;
        
        if (pageIndex > 100) break;
      }
    }

    const title = header ? header.querySelector('h2')?.textContent || 'Untitled' : 'Untitled';
    
    console.log('[EntryColumnFlow] Creating', pages.length, 'pages for', entryId);
    
    pages.forEach((page, idx) => {
      const pageDiv = document.createElement('div');
      pageDiv.className = 'book-column-page';
      pageDiv.dataset.pageType = 'content';
      pageDiv.dataset.entryId = entryId;
      pageDiv.dataset.pageIndex = idx;
      
      const innerDiv = document.createElement('div');
      innerDiv.className = 'book-column-page-inner';
      
      const clickableDiv = document.createElement('div');
      clickableDiv.className = 'cursor-pointer h-full flex flex-col group';
      clickableDiv.addEventListener('click', () => {
        const scrollContainer = document.getElementById('book-scroll-container');
        const currentPage = scrollContainer?.__bookScrollReader?.getCurrentContentPage() || 0;
        window.location.href = `/app/journal/${entryId}?scope=book&book_id=${bookId}&view=reading&page=${currentPage}`;
      });
      
      if (page.isFirst && page.headerHtml) {
        const headerDiv = document.createElement('div');
        headerDiv.className = 'flex-shrink-0';
        headerDiv.innerHTML = page.headerHtml;
        clickableDiv.appendChild(headerDiv);
      } else if (!page.isFirst) {
        const contDiv = document.createElement('div');
        contDiv.className = 'flex items-center gap-2 mb-3 flex-shrink-0';
        contDiv.innerHTML = `<span class="text-sm text-slate-400 dark:text-slate-500 italic">${title} (continued)</span>`;
        clickableDiv.appendChild(contDiv);
      }
      
      const bodyDiv = document.createElement('div');
      bodyDiv.className = 'flex-1 min-h-0 overflow-hidden';
      const bodyInner = document.createElement('div');
      bodyInner.className = 'h-full prose prose-slate dark:prose-invert max-w-none text-base sm:text-lg leading-relaxed';
      bodyInner.innerHTML = page.bodyHtml;
      bodyDiv.appendChild(bodyInner);
      clickableDiv.appendChild(bodyDiv);
      
      const footerDiv = document.createElement('div');
      footerDiv.className = 'flex items-center justify-between pt-2 flex-shrink-0';
      footerDiv.innerHTML = `
        <span class="text-xs font-serif italic text-slate-400 dark:text-slate-500" data-page-num></span>
        <span class="text-xs text-emerald-500 dark:text-emerald-400 opacity-0 group-hover:opacity-100 transition-opacity">Click to read →</span>
      `;
      clickableDiv.appendChild(footerDiv);
      
      innerDiv.appendChild(clickableDiv);
      pageDiv.appendChild(innerDiv);
      wrapper.appendChild(pageDiv);
    });

    this.pagesCreated = true;
    wrapper.dataset.pageCount = pages.length;
    
    console.log('[EntryColumnFlow] Pages created. Wrapper now has', wrapper.children.length, 'children');
    
    const scrollContainer = document.getElementById('book-scroll-container');
    if (scrollContainer && scrollContainer.__bookScrollReader) {
      scrollContainer.__bookScrollReader.recalculatePages();
    }
  },

  splitHtmlToFit(html, width, height) {
    const measureDiv = document.createElement('div');
    measureDiv.style.cssText = `
      position: absolute;
      visibility: hidden;
      width: ${width}px;
      height: auto;
      overflow: visible;
    `;
    measureDiv.className = 'prose prose-slate dark:prose-invert max-w-none text-base sm:text-lg leading-relaxed';
    document.body.appendChild(measureDiv);

    const tempDiv = document.createElement('div');
    tempDiv.innerHTML = html;
    const nodes = Array.from(tempDiv.childNodes);
    
    let splitIndex = nodes.length;
    
    for (let i = 0; i < nodes.length; i++) {
      measureDiv.innerHTML = '';
      const testNodes = nodes.slice(0, i + 1);
      testNodes.forEach(n => measureDiv.appendChild(n.cloneNode(true)));
      const currentHeight = measureDiv.scrollHeight;
      
      if (currentHeight > height) {
        splitIndex = i;
        break;
      }
    }
    
    if (splitIndex === 0 && nodes.length > 0) {
      const firstNode = nodes[0];
      if (firstNode.nodeType === Node.TEXT_NODE) {
        const text = firstNode.textContent;
        const words = text.split(/(\s+)/);
        let usedText = '';
        
        for (let i = 0; i < words.length; i++) {
          measureDiv.textContent = usedText + words[i];
          if (measureDiv.scrollHeight > height) {
            break;
          }
          usedText += words[i];
        }
        
        document.body.removeChild(measureDiv);
        
        if (usedText.trim().length > 0) {
          const leftover = text.slice(usedText.length);
          const leftoverNodes = nodes.slice(1);
          let leftoverHtml = leftover;
          leftoverNodes.forEach(n => {
            if (n.nodeType === Node.ELEMENT_NODE) {
              leftoverHtml += n.outerHTML;
            } else if (n.nodeType === Node.TEXT_NODE) {
              leftoverHtml += n.textContent;
            }
          });
          
          return { usedHtml: usedText, leftoverHtml };
        }
      } else if (firstNode.nodeType === Node.ELEMENT_NODE) {
        document.body.removeChild(measureDiv);
        const leftoverNodes = nodes.slice(1);
        let leftoverHtml = '';
        leftoverNodes.forEach(n => {
          if (n.nodeType === Node.ELEMENT_NODE) {
            leftoverHtml += n.outerHTML;
          } else if (n.nodeType === Node.TEXT_NODE) {
            leftoverHtml += n.textContent;
          }
        });
        return { usedHtml: firstNode.outerHTML, leftoverHtml };
      }
    }
    
    document.body.removeChild(measureDiv);
    
    const usedPart = nodes.slice(0, splitIndex);
    const leftoverPart = nodes.slice(splitIndex);
    
    let usedHtml = '';
    usedPart.forEach(n => {
      if (n.nodeType === Node.ELEMENT_NODE) {
        usedHtml += n.outerHTML;
      } else if (n.nodeType === Node.TEXT_NODE) {
        usedHtml += n.textContent;
      }
    });
    
    let leftoverHtml = '';
    leftoverPart.forEach(n => {
      if (n.nodeType === Node.ELEMENT_NODE) {
        leftoverHtml += n.outerHTML;
      } else if (n.nodeType === Node.TEXT_NODE) {
        leftoverHtml += n.textContent;
      }
    });
    
    return { usedHtml, leftoverHtml };
  }
};

export default EntryColumnFlow;
