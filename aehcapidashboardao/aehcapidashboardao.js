import { LightningElement } from 'lwc';
import getPublishedAPIMatrix from '@salesforce/apex/AEHC_APIDashboardCtrl.getPublishedAPIMatrix';

export default class Aehcapidashboardao extends LightningElement {


    maxHeight = 120;
    totalCount;

    connectedCallback() {

        this.initialize();
    }

    async initialize() {
        try {
            this.totalCount = 0;
            const result = await getPublishedAPIMatrix();

            if (result.status == 200) {
                this.renderData(result.data);
            }
        } catch (err) {
            console.log(err);
        }
    }

    
    renderData(data) {

        const totalBars = Object.keys(data).length;
        let count = 1;
        let totalCount = 0;
        const bars = []
        for (const apiName in data) {
            const color = this.generateColor(count, totalBars);
            bars.push({
                label: apiName,
                value: data[apiName],
                x: count * 20,
                color,
                style: `background:${color};`
            });
            totalCount += data[apiName];
            this.totalCount
            count++;
        }

        this.totalCount = totalCount;
        this.data = bars;
    }

    data = [
    ];

    get bars() {
        const maxValue = Math.max(...this.data.map(d => d.value));

        return this.data.map(d => {
            const height = (d.value / maxValue) * this.maxHeight;
            return {
                ...d,
                height,
                y: 160 - height
            };
        });
    }

    generateColor(index, total) {
        const hue = Math.round((360 / total) * index);
        return `hsl(${hue}, 70%, 50%)`;
    }


}