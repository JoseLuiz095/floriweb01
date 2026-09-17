import type { OpeningDayConfig, OpeningSchedule } from '../types';

const DEFAULT_DAYS = [
  { day: 1, enabled: true, open: '08:00', close: '18:00', breakStart: '', breakEnd: '' },
  { day: 2, enabled: true, open: '08:00', close: '18:00', breakStart: '', breakEnd: '' },
  { day: 3, enabled: true, open: '08:00', close: '18:00', breakStart: '', breakEnd: '' },
  { day: 4, enabled: true, open: '08:00', close: '18:00', breakStart: '', breakEnd: '' },
  { day: 5, enabled: true, open: '08:00', close: '18:00', breakStart: '', breakEnd: '' },
  { day: 6, enabled: true, open: '08:00', close: '14:00', breakStart: '', breakEnd: '' },
  { day: 0, enabled: false, open: '08:00', close: '12:00', breakStart: '', breakEnd: '' },
] as const satisfies readonly OpeningDayConfig[];

const DAY_NAMES = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

const toMinutes = (value: string) => {
  const [hour, minute] = value.split(':').map(Number);
  return hour * 60 + minute;
};

const fromMinutes = (value: number) => {
  const wrapped = ((value % 1440) + 1440) % 1440;
  const hour = Math.floor(wrapped / 60);
  const minute = wrapped % 60;
  return `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
};

const normalizeDay = (day: Partial<OpeningDayConfig> & { day: number }): OpeningDayConfig => ({
  day: day.day,
  enabled: Boolean(day.enabled),
  open: day.open || '08:00',
  close: day.close || '18:00',
  breakStart: day.breakStart || '',
  breakEnd: day.breakEnd || '',
});

const sortDays = (days: OpeningDayConfig[]) => [...days].sort((a, b) => {
  const normalize = (value: number) => (value === 0 ? 7 : value);
  return normalize(a.day) - normalize(b.day);
});

const dayLabel = (day: number) => DAY_NAMES[day] || `Dia ${day}`;

const hasLunchBreak = (day: OpeningDayConfig) => Boolean(day.enabled && day.breakStart && day.breakEnd && day.breakStart !== day.breakEnd);

const getNormalizedRange = (start: number, end: number) => (end <= start ? end + 1440 : end);

const minuteInWindow = (minute: number, start: number, end: number) => {
  const normalizedEnd = getNormalizedRange(start, end);
  const candidate = minute < start ? minute + 1440 : minute;
  return candidate >= start && candidate < normalizedEnd;
};

const formatServiceWindows = (day: OpeningDayConfig) => {
  if (!day.enabled) return 'Fechado';
  if (!hasLunchBreak(day)) return `${day.open}–${day.close}`;
  return `${day.open}–${day.breakStart} · ${day.breakEnd}–${day.close}`;
};

export const openingDayName = (day: number) => {
  const labels: Record<number, string> = {
    0: 'Domingo',
    1: 'Segunda-feira',
    2: 'Terça-feira',
    3: 'Quarta-feira',
    4: 'Quinta-feira',
    5: 'Sexta-feira',
    6: 'Sábado',
  };
  return labels[day] || dayLabel(day);
};

export const normalizeOpeningSchedule = (value: unknown): OpeningSchedule => {
  const fallback: OpeningSchedule = { timezone: 'America/Sao_Paulo', days: DEFAULT_DAYS.map((day) => ({ ...day })) };
  if (!value || typeof value !== 'object') return fallback;
  const source = value as Partial<OpeningSchedule> & { days?: Array<Partial<OpeningDayConfig> & { day: number }> };
  const dayMap = new Map<number, OpeningDayConfig>();
  for (const baseDay of DEFAULT_DAYS) dayMap.set(baseDay.day, { ...baseDay });
  for (const day of source.days || []) if (typeof day?.day === 'number') dayMap.set(day.day, normalizeDay(day));
  return {
    timezone: typeof source.timezone === 'string' && source.timezone ? source.timezone : fallback.timezone,
    days: sortDays(Array.from(dayMap.values())),
  };
};

export const formatOpeningSchedule = (schedule: OpeningSchedule) => {
  const normalized = normalizeOpeningSchedule(schedule);
  const enabled = normalized.days.filter((day) => day.enabled);
  if (!enabled.length) return 'Consulte os horários';
  return enabled.map((day) => `${dayLabel(day.day)} ${formatServiceWindows(day)}`).join(' · ');
};

export const getOpeningScheduleOverview = (schedule: OpeningSchedule, now = new Date()) => {
  const normalized = normalizeOpeningSchedule(schedule);
  const today = now.getDay();
  const days = sortDays(normalized.days).map((day) => ({
    ...day,
    isToday: day.day === today,
    shortLabel: dayLabel(day.day),
    fullLabel: openingDayName(day.day),
    summary: formatServiceWindows(day),
  }));
  return {
    today: days.find((day) => day.isToday) || days[0],
    days,
  };
};

export const getStoreOpenStatus = (schedule: OpeningSchedule, now = new Date()) => {
  const normalized = normalizeOpeningSchedule(schedule);
  const currentDay = now.getDay();
  const currentMinutes = now.getHours() * 60 + now.getMinutes();
  const currentConfig = normalized.days.find((day) => day.day === currentDay);

  const todaySummary = currentConfig ? formatServiceWindows(currentConfig) : 'Fechado hoje';

  if (!currentConfig?.enabled) {
    return { open: false, label: 'Fechado', detail: 'Hoje indisponível', todaySummary };
  }

  const open = toMinutes(currentConfig.open);
  const close = toMinutes(currentConfig.close);
  const isOpenInDay = minuteInWindow(currentMinutes, open, close);
  const lunchActive = hasLunchBreak(currentConfig)
    ? minuteInWindow(currentMinutes, toMinutes(currentConfig.breakStart || '00:00'), toMinutes(currentConfig.breakEnd || '00:00'))
    : false;

  if (!isOpenInDay) {
    const normalizedClose = getNormalizedRange(open, close);
    const normalizedCurrent = currentMinutes < open ? currentMinutes + 1440 : currentMinutes;
    const beforeOpen = normalizedCurrent < open;
    return {
      open: false,
      label: 'Fechado',
      detail: beforeOpen ? `Abre às ${currentConfig.open}` : 'Atendimento encerrado hoje',
      todaySummary,
    };
  }

  if (lunchActive) {
    return {
      open: false,
      label: 'Em almoço',
      detail: `Retorna às ${currentConfig.breakEnd}`,
      todaySummary,
      lunchBreak: true,
    };
  }

  if (hasLunchBreak(currentConfig)) {
    const breakStart = toMinutes(currentConfig.breakStart || '00:00');
    const breakEnd = toMinutes(currentConfig.breakEnd || '00:00');
    const normalizedCurrent = currentMinutes < open ? currentMinutes + 1440 : currentMinutes;
    const normalizedBreakStart = getNormalizedRange(open, breakStart);
    const normalizedBreakEnd = getNormalizedRange(open, breakEnd);
    if (normalizedCurrent < normalizedBreakStart) {
      return {
        open: true,
        label: 'Aberto',
        detail: `Pausa às ${fromMinutes(breakStart)}`,
        todaySummary,
      };
    }
    if (normalizedCurrent >= normalizedBreakEnd) {
      return {
        open: true,
        label: 'Aberto',
        detail: `Fecha às ${fromMinutes(close)}`,
        todaySummary,
      };
    }
  }

  return {
    open: true,
    label: 'Aberto',
    detail: `Fecha às ${fromMinutes(close)}`,
    todaySummary,
  };
};
