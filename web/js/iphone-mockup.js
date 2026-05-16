/**
 * CSS 3D iPhone Mockup Component
 * Pure CSS 3D transforms with vanilla JS initialization
 */

class IPhoneMockup {
  constructor(options = {}) {
    this.screenshot1 = options.screenshot1 || '';
    this.screenshot2 = options.screenshot2 || '';
    this.containerId = options.containerId || 'iphone-mockup-container';
    this.containerSize = options.containerSize || 'medium'; // small, medium, large
  }

  render() {
    const container = document.getElementById(this.containerId);
    if (!container) {
      console.error(`Container with id "${this.containerId}" not found`);
      return;
    }

    // Set container size class
    container.classList.add(`mockup-${this.containerSize}`);

    // Create the mockup HTML
    const mockupHTML = `
      <div class="iphone-mockup-scene">
        <!-- Front iPhone -->
        <div class="iphone-frame iphone-front">
          <div class="iphone-bezel">
            <div class="dynamic-island"></div>
            <div class="iphone-screen">
              <img src="${this.screenshot1}" alt="App Screenshot 1" class="screenshot" />
            </div>
          </div>
          <div class="iphone-button iphone-volume-up"></div>
          <div class="iphone-button iphone-volume-down"></div>
          <div class="iphone-button iphone-power"></div>
        </div>

        <!-- Back iPhone -->
        <div class="iphone-frame iphone-back">
          <div class="iphone-bezel">
            <div class="dynamic-island"></div>
            <div class="iphone-screen">
              <img src="${this.screenshot2}" alt="App Screenshot 2" class="screenshot" />
            </div>
          </div>
          <div class="iphone-button iphone-volume-up"></div>
          <div class="iphone-button iphone-volume-down"></div>
          <div class="iphone-button iphone-power"></div>
        </div>
      </div>
    `;

    container.innerHTML = mockupHTML;
  }
}

// Auto-initialize on DOM ready
document.addEventListener('DOMContentLoaded', () => {
  // This allows easy initialization with data attributes
  const mockupContainers = document.querySelectorAll('[data-mockup="iphone"]');
  mockupContainers.forEach(container => {
    const mockup = new IPhoneMockup({
      screenshot1: container.dataset.screenshot1 || '',
      screenshot2: container.dataset.screenshot2 || '',
      containerId: container.id,
      containerSize: container.dataset.size || 'medium'
    });
    mockup.render();
  });
});
