/**
 * Component: aehcScheduleStep
 * Author: Umang Rohitbhai Fofariya
 * Date: 24-May-2026
 *
 * Description:
 * Handles schedule configuration for publication/subscription.
 * Supports multiple frequency types and generates cron expressions.
 */
import { LightningElement, api, track } from 'lwc';
import logError from "@salesforce/apex/AEHC_Logger.logError";
import LABEL_ENV_NAME from '@salesforce/label/c.AEHC_Environment_Name';
import L_PUBLISHER_SCHEDULE from '@salesforce/label/c.AEHC_DP_PublisherSchedule';
import L_COMPLETION_WINDOW from '@salesforce/label/c.AEHC_DP_CompletionWindow';
import L_PRO_TIP from '@salesforce/label/c.AEHC_DP_ProTip';
import L_FREQUENCY from '@salesforce/label/c.AEHC_DP_Frequency';
import L_TIME24 from '@salesforce/label/c.AEHC_DP_Time24';
import L_WEEKDAYS from '@salesforce/label/c.AEHC_DP_Weekdays';
import L_WEEKS from '@salesforce/label/c.AEHC_DP_Weeks';
import L_DAY_OF_MONTH from '@salesforce/label/c.AEHC_DP_DayOfMonth';
import L_EXEC_DATE from '@salesforce/label/c.AEHC_DP_ExecDate';
import L_EXEC_TIME from '@salesforce/label/c.AEHC_DP_ExecTime';
import L_SCHEDULE_SUMMARY from '@salesforce/label/c.AEHC_DP_ScheduleSummary';
import L_SUBMON_INFO from '@salesforce/label/c.AEHC_DP_SubmonInfo';
import L_BACK from '@salesforce/label/c.AEHC_DP_Back';
import L_NEXT from '@salesforce/label/c.AEHC_DP_Next';


export default class AehcScheduleStep extends LightningElement {
    @api recordId;
    @api schedulerModeOptions = [];
    @api frequencyOptions = [];
    @api weekdayOptions = [];
    @api weekOptions = [];
    @api monthDayOptions = [];
    @api mode = 'subscription'; // default
    @api publisherScheduleData;
    @track localWizardData = {};
    @track localSchedule = {
        schedulerMode: 'Scheduler (Time-Based)',
        frequency: 'Daily',
        scheduleTime: '',
        weekdays: [],
        multiWeekWeeks: [],
        multiWeekDays: [],
        monthlyDay: '',
        oneTimeDate: '',
        oneTimeTime: '',
        scheduleSummary: '',
        annualDate: '',
        cronExpression: ''
    };

    uiLabels = {
        publisherSchedule: L_PUBLISHER_SCHEDULE,
        completionWindow: L_COMPLETION_WINDOW,
        proTip: L_PRO_TIP,
        frequency: L_FREQUENCY,
        time24: L_TIME24,
        weekdays: L_WEEKDAYS,
        weeks: L_WEEKS,
        dayOfMonth: L_DAY_OF_MONTH,
        execDate: L_EXEC_DATE,
        execTime: L_EXEC_TIME,
        scheduleSummary: L_SCHEDULE_SUMMARY,
        submonInfo: L_SUBMON_INFO,
        back: L_BACK,
        next: L_NEXT
    };
    get publisherSchedule() {
        return this.publisherScheduleData?.scheduleSummary || '';
    }

    get typicalCompletionWindow() {

        const timeStr = this.publisherScheduleData?.scheduleTime;

        if (!timeStr) return '';

        try {
            const [hour, minute] = timeStr.split(':').map(n => parseInt(n, 10));


            let start = new Date();
            start.setHours(hour, minute, 0);

            let end = new Date(start);
            end.setMinutes(end.getMinutes() + 60);

            const format = (date) => {
                const h = String(date.getHours()).padStart(2, '0');
                const m = String(date.getMinutes()).padStart(2, '0');
                return `${h}${m}`;
            };

            return `${format(start)} to ${format(end)} EST`;

        } catch (e) {
            return '';
        }
    }


    get publisherProTip() {
        return 'Schedule output 1 hour after publication schedule to allow for publication run to complete.';
    }

    get publisherScheduleCron() {
        return this.publisherScheduleData?.cronExpression || '';
    }

    get filteredFrequencyOptions() {
        if (this.mode === 'publication') {
            return (this.frequencyOptions || []).filter(opt => opt.value !== 'One-Time Load');
        }
        return this.frequencyOptions;
    }

    @api
    set wizardData(value) {
        if (value) {
            this.localWizardData = { ...value };

            // Handle both cases: value is already schedule data OR value has a schedule property
            const scheduleData = value.schedule || value;
            const normalizedSchedule = {
                ...scheduleData,
                weekdays: this.normalizeScheduleList(scheduleData?.weekdays),
                multiWeekDays: this.normalizeScheduleList(scheduleData?.multiWeekDays || scheduleData?.weekdays),
                multiWeekWeeks: this.normalizeScheduleList(scheduleData?.multiWeekWeeks || scheduleData?.weeks)
            };

            this.localSchedule = {
                ...this.localSchedule,
                ...normalizedSchedule
            };

            this.updateScheduleSummary();
        }
    }

    get wizardData() {
        return this.localWizardData;
    }

    get showPublisherGuidance() {
        return this.mode === 'subscription' &&
            (!!this.publisherSchedule || !!this.typicalCompletionWindow);
    }


    get isTimeBasedScheduler() {
        return this.localSchedule.schedulerMode === 'Scheduler (Time-Based)';
    }

    get isSubmonScheduler() {
        return this.localSchedule.schedulerMode === 'Submon (Triggered on Publication Completion)';
    }

    get isDaily() {
        return this.localSchedule.frequency === 'Daily';
    }

    get isWeekly() {
        return this.localSchedule.frequency === 'Weekly';
    }

    get isMultiWeek() {
        return this.localSchedule.frequency === 'Multi-Weekly';
    }

    get isMonthly() {
        return this.localSchedule.frequency === 'Monthly';
    }

    get isOneTime() {
        return this.mode === 'subscription' &&
            this.localSchedule.frequency === 'One-Time Load';
    }

    get scheduleSummary() {
        return this.localSchedule.scheduleSummary;
    }
    get todayDate() {
        return new Date().toISOString().split('T')[0];
    }
    get showSchedulerMode() {
        return this.mode === 'subscription';
    }
    get isAnnual() {
        return this.localSchedule.frequency === 'Annual';
    }
    get annualMonthOptions() {
        return [
            { label: 'Jan', value: '1' },
            { label: 'Feb', value: '2' },
            { label: 'Mar', value: '3' },
            { label: 'Apr', value: '4' },
            { label: 'May', value: '5' },
            { label: 'Jun', value: '6' },
            { label: 'Jul', value: '7' },
            { label: 'Aug', value: '8' },
            { label: 'Sep', value: '9' },
            { label: 'Oct', value: '10' },
            { label: 'Nov', value: '11' },
            { label: 'Dec', value: '12' }
        ];
    }

    handleAnnualMonthChange(event) {
        this.localSchedule = {
            ...this.localSchedule,
            annualMonth: event.detail.value
        };
        this.refreshScheduleState();
    }

    handleAnnualDayChange(event) {
        this.localSchedule = {
            ...this.localSchedule,
            annualDay: event.target.value
        };
        this.refreshScheduleState();
    }
    connectedCallback() {
        if (this.mode === 'publication') {
            this.localSchedule.schedulerMode = 'Scheduler (Time-Based)';
        }
    }


    handleSchedulerModeChange(event) {
        const schedulerMode = event.detail.value;

        if (schedulerMode === 'Submon (Triggered on Publication Completion)') {
            const pub = this.publisherScheduleData || {};
            this.localSchedule = {
                schedulerMode: 'Submon (Triggered on Publication Completion)',
                frequency: pub.frequency || '',
                scheduleTime: pub.scheduleTime || '',
                weekdays: pub.weekdays || [],
                multiWeekWeeks: pub.multiWeekWeeks || [],
                multiWeekDays: pub.multiWeekDays || [],
                monthlyDay: pub.monthlyDay || '',
                oneTimeDate: pub.oneTimeDate || '',
                oneTimeTime: pub.oneTimeTime || '',
                annualDate: pub.annualDate || '',
                scheduleSummary: pub.scheduleSummary || 'Triggered on publisher completion.',
                cronExpression: pub.cronExpression || ''
            };
        } else {
            this.localSchedule = {
                schedulerMode: 'Scheduler (Time-Based)',
                frequency: this.frequencyOptions?.[0]?.value || 'Daily',
                scheduleTime: '',
                weekdays: [],
                multiWeekWeeks: [],
                multiWeekDays: [],
                monthlyDay: '',
                oneTimeDate: '',
                oneTimeTime: '',
                scheduleSummary: '',
                cronExpression: ''
            };
        }

        this.refreshScheduleState();
    }

    handleFrequencyChange(event) {
        this.localSchedule = {
            ...this.localSchedule,
            frequency: event.detail.value,
            scheduleTime: '',
            weekdays: [],
            multiWeekWeeks: [],
            multiWeekDays: [],
            monthlyDay: '',
            oneTimeDate: '',
            oneTimeTime: '',
            scheduleSummary: ''
        };
        if (this.mode === 'publication' && event.detail.value === 'One-Time Load') {
            return;
        }

        this.refreshScheduleState();
    }

    getInputValue(event) {
        return event.detail?.value || event.target?.value || '';
    }

    handleScheduleTimeChange(event) {
        const value = this.getInputValue(event);

        this.localSchedule = {
            ...this.localSchedule,
            scheduleTime: value
        };

        this.refreshScheduleState();
    }

    handleWeekdaysChange(event) {
        const value = event.detail?.value || [];

        this.localSchedule = {
            ...this.localSchedule,
            weekdays: value
        };

        this.refreshScheduleState();
    }


    handleMultiWeekWeeksChange(event) {
        const value = event.detail?.value || [];

        this.localSchedule = {
            ...this.localSchedule,
            multiWeekWeeks: value
        };

        this.refreshScheduleState();
    }

    handleMultiWeekDaysChange(event) {
        const value = event.detail?.value || [];

        this.localSchedule = {
            ...this.localSchedule,
            multiWeekDays: value
        };

        this.refreshScheduleState();
    }
    handleMonthlyDayChange(event) {
        const value = event.detail?.value || '';

        this.localSchedule = {
            ...this.localSchedule,
            monthlyDay: value
        };

        this.refreshScheduleState();
    }

    handleOneTimeDateChange(event) {
        try {
            const value = event.detail?.value || event.target?.value || '';

            this.localSchedule = {
                ...this.localSchedule,
                oneTimeDate: value
            };

            this.refreshScheduleState();

        } catch (error) {
            this.logExceptionToApex(error, 'handleOneTimeDateChange');
        }
    }

    handleOneTimeTimeChange(event) {

        const value = this.getInputValue(event);

        this.localSchedule = {
            ...this.localSchedule,
            oneTimeTime: value
        };

        this.refreshScheduleState();

    }

    updateScheduleSummary() {
        if (this.localSchedule.schedulerMode === 'Submon (Triggered on Publication Completion)') {
            this.localSchedule = {
                ...this.localSchedule,
                scheduleSummary: 'Triggered on publisher completion.'
            };
            return;
        }

        let summary = '';

        if (this.localSchedule.frequency === 'Daily') {
            summary = this.localSchedule.scheduleTime
                ? `Runs daily at ${this.localSchedule.scheduleTime}.`
                : '';
        }

        if (this.localSchedule.frequency === 'Weekly') {
            summary = this.localSchedule.weekdays?.length && this.localSchedule.scheduleTime
                ? `Runs weekly on ${this.localSchedule.weekdays.join(', ')} at ${this.localSchedule.scheduleTime}.`
                : '';
        }

        if (this.localSchedule.frequency === 'Multi-Weekly') {
            summary = this.localSchedule.multiWeekWeeks?.length &&
                this.localSchedule.multiWeekDays?.length &&
                this.localSchedule.scheduleTime
                ? `Runs multi-week during ${this.localSchedule.multiWeekWeeks.join(', ')} on ${this.localSchedule.multiWeekDays.join(', ')} at ${this.localSchedule.scheduleTime}.`
                : '';
        }

        if (this.localSchedule.frequency === 'Monthly') {
            summary = this.localSchedule.monthlyDay && this.localSchedule.scheduleTime
                ? `Runs monthly on day ${this.localSchedule.monthlyDay} at ${this.localSchedule.scheduleTime}.`
                : '';
        }
        if (this.localSchedule.frequency === 'Annual') {
            summary =
                this.localSchedule.annualDate

                    ? `Runs annually on ${this.localSchedule.annualDate} at ${this.localSchedule.scheduleTime}.`
                    : '';

        }

        if (this.mode === 'subscription' && this.localSchedule.frequency === 'One-Time Load') {
            summary = this.localSchedule.oneTimeDate && this.localSchedule.oneTimeTime
                ? `Runs once on ${this.localSchedule.oneTimeDate} at ${this.localSchedule.oneTimeTime}.`
                : '';
        }

        this.localSchedule = {
            ...this.localSchedule,
            scheduleSummary: summary
        };
    }

    get disableNext() {
        if (this.localSchedule.schedulerMode === 'Submon (Triggered on Publication Completion)') {
            return false;
        }

        if (this.localSchedule.frequency === 'Daily') {
            return !this.localSchedule.scheduleTime;
        }

        if (this.localSchedule.frequency === 'Weekly') {
            return !this.localSchedule.weekdays?.length ||
                !this.localSchedule.scheduleTime;
        }

        if (this.localSchedule.frequency === 'Multi-Weekly') {
            return !this.localSchedule.multiWeekWeeks?.length ||
                !this.localSchedule.multiWeekDays?.length ||
                !this.localSchedule.scheduleTime;
        }

        if (this.localSchedule.frequency === 'Monthly') {
            return !this.localSchedule.monthlyDay ||
                !this.localSchedule.scheduleTime;
        }

        if (this.localSchedule.frequency === 'One-Time Load') {

            const date = this.localSchedule.oneTimeDate;
            const time = this.localSchedule.oneTimeTime;

            if (!date || !time) {
                return true;
            }

            const selected = new Date(`${date}T${time}`);
            const now = new Date();

            return selected < now;

        }
        if (this.localSchedule.frequency === 'Annual') {
            if (!this.localSchedule.annualDate || !this.localSchedule.scheduleTime) {
                return true;
            }

            const selected = new Date(`${this.localSchedule.annualDate}T${this.localSchedule.scheduleTime}`);
            return selected < new Date();
        }


        return true;
    }

    notifyParent() {
        this.dispatchEvent(
            new CustomEvent('stepdatachange', {
                detail: {
                    schedule: {
                        ...this.localSchedule
                    }
                }
            })
        );
    }
    handleAnnualDateChange(event) {
        const value = event.detail?.value || event.target?.value || '';

        this.localSchedule = {
            ...this.localSchedule,
            annualDate: value
        };

        this.refreshScheduleState();
    }

    handleBack() {
        this.notifyParent();
        this.dispatchEvent(new CustomEvent('back'));
    }

    handleNext() {
        this.notifyParent();
        this.dispatchEvent(new CustomEvent('next'));
    }
    parseTimeValue(timeValue) {
        if (!timeValue) {
            return null;
        }

        const cleanTime = String(timeValue).split('.')[0];
        const parts = cleanTime.split(':');

        if (parts.length < 2) {
            return null;
        }

        return {
            hour: parts[0],
            minute: parts[1]
        };
    }
    getCronDayOfWeek(day) {
        const dayMap = {
            Monday: 'MON',
            Tuesday: 'TUE',
            Wednesday: 'WED',
            Thursday: 'THU',
            Friday: 'FRI',
            Saturday: 'SAT',
            Sunday: 'SUN',

            // Backward compatibility
            MONDAY: 'MON',
            TUESDAY: 'TUE',
            WEDNESDAY: 'WED',
            THURSDAY: 'THU',
            FRIDAY: 'FRI',
            SATURDAY: 'SAT',
            SUNDAY: 'SUN'
        };

        return dayMap[day] || day;
    }
    buildCronExpression() {

        if (this.localSchedule.schedulerMode === 'Submon (Triggered on Publication Completion)') {
            return this.publisherScheduleCron || '';
        }

        const frequency = this.localSchedule.frequency;

        if (frequency === 'Daily') {
            const time = this.parseTimeValue(this.localSchedule.scheduleTime);

            if (!time) {
                return '';
            }

            return `0 ${time.minute} ${time.hour} * * ?`;
        }

        if (frequency === 'Weekly') {
            const time = this.parseTimeValue(this.localSchedule.scheduleTime);

            if (!time || !this.localSchedule.weekdays?.length) {
                return '';
            }

            const days = this.localSchedule.weekdays
                .map(day => this.getCronDayOfWeek(day))
                .join(',');

            return `0 ${time.minute} ${time.hour} ? * ${days}`;
        }

        if (frequency === 'Multi-Weekly') {
            const time = this.parseTimeValue(this.localSchedule.scheduleTime);

            if (
                !time ||
                !this.localSchedule.multiWeekWeeks?.length ||
                !this.localSchedule.multiWeekDays?.length
            ) {
                return '';
            }

            const cronValues = [];

            this.localSchedule.multiWeekWeeks.forEach(week => {
                const weekNumber = this.getWeekNumberForCron(week);

                this.localSchedule.multiWeekDays.forEach(day => {
                    const cronDay = this.getCronDayOfWeek(day);

                    cronValues.push(
                        `0 ${time.minute} ${time.hour} ? * ${cronDay}#${weekNumber}`
                    );
                });
            });

            return cronValues.join('; ');
        }

        if (frequency === 'Monthly') {
            const time = this.parseTimeValue(this.localSchedule.scheduleTime);

            if (!time || !this.localSchedule.monthlyDay) {
                return '';
            }

            return `0 ${time.minute} ${time.hour} ${this.localSchedule.monthlyDay} * ?`;
        }



        if (frequency === 'Annual') {
            const time = this.parseTimeValue(this.localSchedule.scheduleTime);
            const dateValue = this.localSchedule.annualDate;

            if (!time || !dateValue) {
                return '';
            }

            const [year, month, day] = dateValue.split('-');

            return `0 ${time.minute} ${time.hour} ${day} ${month} ?`;
        }


        if (this.mode === 'subscription' && frequency === 'One-Time Load') {
            const dateValue = this.localSchedule.oneTimeDate;
            const time = this.parseTimeValue(this.localSchedule.oneTimeTime);

            if (!dateValue || !time) {
                return '';
            }

            const dateParts = dateValue.split('-');

            if (dateParts.length !== 3) {
                return '';
            }

            const year = dateParts[0];
            const month = dateParts[1];
            const day = dateParts[2];

            return `0 ${time.minute} ${time.hour} ${day} ${month} ? ${year}`;
        }
        return '';
    }
    logCronExpression() {
        const cronExpression = this.buildCronExpression();
    }

    refreshScheduleState() {
        this.updateScheduleSummary();

        const cronExpression = this.buildCronExpression();

        this.localSchedule = {
            ...this.localSchedule,
            cronExpression: cronExpression
        };

        console.log('Selected Schedule:', JSON.parse(JSON.stringify(this.localSchedule)));
        console.log('Generated Cron Expression:', cronExpression);

        this.notifyParent();
    }
    getWeekNumberForCron(weekValue) {
        const weekMap = {
            'Week 1': '1',
            'Week 2': '2',
            'Week 3': '3',
            'Week 4': '4',
            'Week 5': '5',

            // Backward compatibility
            WEEK_1: '1',
            WEEK_2: '2',
            WEEK_3: '3',
            WEEK_4: '4',
            WEEK_5: '5'
        };

        return weekMap[weekValue] || weekValue;
    }

    normalizeErrorMessage(error) {
        if (error?.body?.message) {
            return error.body.message;
        }

        if (Array.isArray(error?.body)) {
            return error.body.map(item => item.message).join(', ');
        }

        if (error?.message) {
            return error.message;
        }

        return 'Unknown error';
    }
    logExceptionToApex(error, operation = 'unknown', extraContext = {}) {
        try {
            const transactionContext = {
                schedulerMode: this.localSchedule?.schedulerMode,
                frequency: this.localSchedule?.frequency,
                scheduleTime: this.localSchedule?.scheduleTime,
                weekdays: this.localSchedule?.weekdays,
                multiWeekWeeks: this.localSchedule?.multiWeekWeeks,
                multiWeekDays: this.localSchedule?.multiWeekDays,
                monthlyDay: this.localSchedule?.monthlyDay,
                oneTimeDate: this.localSchedule?.oneTimeDate,
                oneTimeTime: this.localSchedule?.oneTimeTime,
                scheduleSummary: this.localSchedule?.scheduleSummary,
                ...extraContext
            };

            logError({
                message: this.normalizeErrorMessage(error),
                componentType: 'LWC',
                componentName: 'aehcScheduleStep',
                operation: operation,
                recordId: this.recordId || null,
                severity: 'High',
                category: 'UI',
                transactionContext: JSON.stringify(transactionContext),
                orgEnv: LABEL_ENV_NAME
            }).catch((loggingError) => {
                console.error('Failed to log error in Apex', loggingError);
            });

        } catch (localLoggingError) {
            console.error('Local logging failed', localLoggingError);
        }
    }
    get showFooter() {
        return this.mode === 'subscription';
    }

    normalizeScheduleList(value) {
        if (Array.isArray(value)) {
            return value;
        }

        if (typeof value === 'string') {
            return value
                .split(';')
                .map(item => item.trim())
                .filter(item => item);
        }

        return [];
    }
}