import { LightningElement, track } from 'lwc';
import getSubscriptionSummary from '@salesforce/apex/AEHC_SubscriptionControllerAO.getSubscriptionSummary';

export default class Aehcsubscriptionsummaryaopie extends LightningElement {
    @track segments = [];
    @track legendItems = [];
    @track totalSubscribers = 0;

    connectedCallback() {

        this.initialize();
    }

    async initialize() {
        try {
            const result = await getSubscriptionSummary();


            if (result.status == 200) {
                this.renderData(result.data);
            }
        } catch (err) {
            console.log(err);
        }
    }


    renderData(data) {
        const labels = Object.keys(data);
        const totalItems = labels.length;

        let startAngle = 0;
        this.totalSubscribers = Object.values(data).reduce((sum, v) => sum + v, 0);

        this.segments = [];
        this.legendItems = [];

        labels.forEach((label, index) => {
            const value = data[label];
            const percent = value / this.totalSubscribers;
            const angle = percent * 360;
            const endAngle = startAngle + angle;

            // ✅ Generate unique color (no repetition)
            const color = this.generateColor(index, totalItems);

            // Pie arc
            const d = this.describeArc(90, 90, 80, startAngle, endAngle);

            // Label inside arc
            const midAngle = startAngle + angle / 2;
            const labelPoint = this.polarToCartesian(90, 90, 50, midAngle);

            this.segments.push({
                d,
                color,
                percent: Math.round(percent * 100),
                labelX: labelPoint.x,
                labelY: labelPoint.y
            });

            // Legend

            this.legendItems.push({
                label,
                count: value,
                color,
                style: `background:${color};`
            });


            startAngle = endAngle;
        });
    }

    // ✅ Dynamic HSL color generator (no repeated colors)
    generateColor(index, total) {
        const hue = Math.round((360 / total) * index);
        return `hsl(${hue}, 70%, 50%)`;
    }

    // SVG arc path
    describeArc(cx, cy, r, startAngle, endAngle) {
        const start = this.polarToCartesian(cx, cy, r, endAngle);
        const end = this.polarToCartesian(cx, cy, r, startAngle);
        const largeArc = endAngle - startAngle > 180 ? 1 : 0;

        return `M ${cx} ${cy}
                L ${start.x} ${start.y}
                A ${r} ${r} 0 ${largeArc} 0 ${end.x} ${end.y}
                Z`;
    }

    polarToCartesian(cx, cy, r, angle) {
        const rad = (angle - 90) * Math.PI / 180;
        return {
            x: cx + r * Math.cos(rad),
            y: cy + r * Math.sin(rad)
        };
    }
}