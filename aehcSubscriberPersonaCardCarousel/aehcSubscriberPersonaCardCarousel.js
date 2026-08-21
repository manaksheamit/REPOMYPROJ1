import { LightningElement, api } from 'lwc';

export default class AehcSubscriberPersonaCardCarousel extends LightningElement {
  @api applicationName;
  @api publicationName;
  @api schedule;
  @api lastUpdated;
  @api url;

  @api
  get color() {
    return "#2EC4B6";
  }

  @api
  get iconName() {
    return "utility:apps";
  }

  @api
  get cardStyle() {
    return `--card-color:${this.color}`;
  }

  @api
  get iconStyle() {
    return `background:${this.color}`;
  }

  @api
  get topLineStyle() {
    return `background:${this.color}`;
  }

  @api
  handleClick() {
    if (!this.url) return;
    let targetUrl = this.url.trim();
    if (!targetUrl.startsWith("http")) {
      targetUrl = "https://" + targetUrl;
    }
    window.open(targetUrl, "_self");
  }

}