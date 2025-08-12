import Chart from 'chart.js/auto'

const AccuracyChart = {
  mounted() { this.renderChart(); },
  updated() { this.renderChart(); },
  renderChart() {
    const rawData = this.el.dataset.chart;
    const data = JSON.parse(rawData);
    const patientName = this.el.dataset.patient || "Este Paciente";
    const labels = data.map(d => d.task_name);
    let datasets = [{
      label: patientName,
      data: data.map(d => d.avg_accuracy !== undefined && d.avg_accuracy !== null
        ? (d.avg_accuracy * 100).toFixed(2) : null),
      backgroundColor: 'rgba(54, 162, 235, 0.7)',
      borderColor: 'rgba(54, 162, 235, 1)',
      borderWidth: 1,
      barPercentage: 0.75,
      categoryPercentage: 0.75
    }];
    if (data.length && "general_avg_accuracy" in data[0]) {
      datasets.push({
        label: 'Média Geral',
        data: data.map(d => d.general_avg_accuracy !== undefined && d.general_avg_accuracy !== null
          ? (d.general_avg_accuracy * 100).toFixed(2) : null),
        backgroundColor: 'rgba(255, 193, 7, 0.7)',
        borderColor: 'rgba(255, 193, 7, 1)',
        borderWidth: 1,
        barPercentage: 0.75,
        categoryPercentage: 0.75
      });
    }
    if (data.length && "diagnostic_accuracy" in data[0]) {
      datasets.push({
        label: 'Teste Diagnóstico',
        data: data.map(d => d.diagnostic_accuracy !== undefined && d.diagnostic_accuracy !== null
          ? (d.diagnostic_accuracy * 100).toFixed(2) : null),
        backgroundColor: 'rgba(255, 99, 132, 0.7)',
        borderColor: 'rgba(255, 99, 132, 1)',
        borderWidth: 1,
        barPercentage: 0.75,
        categoryPercentage: 0.75
      });
    }
    if (data.length && "ageband_avg_accuracy" in data[0]) {
      datasets.push({
        label: 'Faixa Etária',
        data: data.map(d =>
          d.ageband_avg_accuracy !== undefined && d.ageband_avg_accuracy !== null
            ? (d.ageband_avg_accuracy * 100).toFixed(2)
            : null
        ),
        backgroundColor: 'rgba(40, 167, 69, 0.7)',
        borderColor: 'rgba(40, 167, 69, 1)',
        borderWidth: 1,
        barPercentage: 0.75,
        categoryPercentage: 0.75
      });
    }

    const ctx = this.el.getContext("2d");
    if (window.accuracyChartInstance) window.accuracyChartInstance.destroy();
    window.accuracyChartInstance = new Chart(ctx, {
      type: 'bar',
      data: { labels: labels, datasets: datasets },
      options: {
        responsive: true,
        scales: {
          y: { beginAtZero: true, max: 100 }
        }
      }
    });
  }
}

const ReactionChart = {
  mounted() { this.renderChart(); },
  updated() { this.renderChart(); },
  renderChart() {
    const rawData = this.el.dataset.chart;
    const data = JSON.parse(rawData);
    const patientName = this.el.dataset.patient || "Este Paciente";
    const labels = data.map(d => d.task_name);
    let datasets = [{
      label: patientName,
      data: data.map(d => d.avg_reaction_time !== undefined && d.avg_reaction_time !== null
        ? parseFloat((d.avg_reaction_time / 1000).toFixed(2))
        : null),
      backgroundColor: 'rgba(153, 102, 255, 0.7)',
      borderColor: 'rgba(153, 102, 255, 1)',
      borderWidth: 1,
      barPercentage: 0.75,
      categoryPercentage: 0.75
    }];
    if (data.length && "general_avg_reaction_time" in data[0]) {
      datasets.push({
        label: 'Média Geral',
        data: data.map(d => d.general_avg_reaction_time !== undefined && d.general_avg_reaction_time !== null
          ? parseFloat((d.general_avg_reaction_time / 1000).toFixed(2))
          : null),
        backgroundColor: 'rgba(255, 193, 7, 0.7)',
        borderColor: 'rgba(255, 193, 7, 1)',
        borderWidth: 1,
        barPercentage: 0.75,
        categoryPercentage: 0.75
      });
    }

    if (data.length && "diagnostic_reaction_time" in data[0]) {
      datasets.push({
        label: 'Teste Diagnóstico',
        data: data.map(d => d.diagnostic_reaction_time !== undefined && d.diagnostic_reaction_time !== null
          ? parseFloat((d.diagnostic_reaction_time / 1000).toFixed(2))
          : null),
        backgroundColor: 'rgba(255, 99, 132, 0.7)',
        borderColor: 'rgba(255, 99, 132, 1)',
        borderWidth: 1,
        barPercentage: 0.75,
        categoryPercentage: 0.75
      });
    }

    if (data.length && "ageband_avg_reaction_time" in data[0]) {
      datasets.push({
        label: 'Faixa Etária',
        data: data.map(d =>
          d.ageband_avg_reaction_time !== undefined && d.ageband_avg_reaction_time !== null
            ? parseFloat((d.ageband_avg_reaction_time / 1000).toFixed(2))
            : null
        ),
        backgroundColor: 'rgba(40, 167, 69, 0.7)',
        borderColor: 'rgba(40, 167, 69, 1)',
        borderWidth: 1,
        barPercentage: 0.75,
        categoryPercentage: 0.75
      });
    }

    const ctx = this.el.getContext("2d");
    if (window.reactionChartInstance) window.reactionChartInstance.destroy();
    window.reactionChartInstance = new Chart(ctx, {
      type: 'bar',
      data: { labels: labels, datasets: datasets },
      options: {
        responsive: true,
        scales: { y: { beginAtZero: true } }
      }
    });
  }
}

const PieChart = {
  mounted() { this.renderChart(); },
  updated() {
    if (this.chart) this.chart.destroy();
    this.renderChart();
  },
  renderChart() {
    const rawData = this.el.dataset.chart;
    const data = JSON.parse(rawData);
    const labels = data.map(d => d.label);
    const values = data.map(d => d.percent);
    const canvas = this.el;

    setTimeout(() => {
      const ctx = canvas.getContext("2d");
      this.chart = new Chart(ctx, {
        type: 'pie',
        data: {
          labels: labels,
          datasets: [{
            data: values,
            backgroundColor: [
              '#FF6384', '#36A2EB', '#FFCE56', '#8BC34A', '#FF9800', '#9C27B0', '#00BCD4'
            ],
          }]
        },
        options: {
          responsive: true,
          plugins: { legend: { position: 'bottom' } }
        }
      });
    }, 100);
  }
}

const AccuracyStatChart = {
  mounted() {
    console.log("AccuracyStatChart mounted");
    const rawData = this.el.dataset.chart;
    const data = JSON.parse(rawData);
    const labels = data.map(d => d.task_name);
    const values = data.map(d => (d.avg_accuracy * 100).toFixed(2));

    const ctx = this.el.getContext("2d");
    if (window.accuracyChartInstance) window.accuracyChartInstance.destroy();

    window.accuracyChartInstance = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: labels,
        datasets: [{
          label: 'Precisão Média (%)',
          data: values,
          backgroundColor: 'rgba(54, 162, 235, 0.6)',
          borderColor: 'rgba(54, 162, 235, 1)',
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        scales: {
          y: { beginAtZero: true, max: 100 }
        }
      }
    });
  },
  updated() {
    console.log("AccuracyStatChart updated");
    const rawData = this.el.dataset.chart;
    const data = JSON.parse(rawData);
    const labels = data.map(d => d.task_name);
    const values = data.map(d => (d.avg_accuracy * 100).toFixed(2));

    const ctx = this.el.getContext("2d");
    if (window.accuracyChartInstance) window.accuracyChartInstance.destroy();

    window.accuracyChartInstance = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: labels,
        datasets: [{
          label: 'Precisão Média (%)',
          data: values,
          backgroundColor: 'rgba(54, 162, 235, 0.6)',
          borderColor: 'rgba(54, 162, 235, 1)',
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        scales: {
          y: { beginAtZero: true, max: 100 }
        }
      }
    });
  }
};

const ReactionStatChart = {
  mounted() {
    console.log("ReactionStatChart mounted");
    const rawData = this.el.dataset.chart;
    const field = this.el.dataset.field || "avg_reaction_time";
    const label = this.el.dataset.label || "Tempo Médio (ms)";
    const data = JSON.parse(rawData);

    const labels = data.map(d => d.task_name);
    const values = data.map(d => {
      const val = d[field];
      return val !== null ? parseFloat(val.toFixed(2)) : null;
    });

    const ctx = this.el.getContext("2d");
    if (window.reactionChartInstance) window.reactionChartInstance.destroy();

    window.reactionChartInstance = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: labels,
        datasets: [{
          label: label,
          data: values,
          backgroundColor: 'rgba(153, 102, 255, 0.6)',
          borderColor: 'rgba(153, 102, 255, 1)',
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        scales: {
          y: { beginAtZero: true }
        }
      }
    });
  },
  updated() {
    console.log("ReactionStatChart updated");
    const rawData = this.el.dataset.chart;
    const field = this.el.dataset.field || "avg_reaction_time";
    const label = this.el.dataset.label || "Tempo Médio (ms)";
    const data = JSON.parse(rawData);

    const labels = data.map(d => d.task_name);
    const values = data.map(d => {
      const val = d[field];
      return val !== null ? parseFloat(val.toFixed(2)) : null;
    });

    const ctx = this.el.getContext("2d");
    if (window.reactionChartInstance) window.reactionChartInstance.destroy();

    window.reactionChartInstance = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: labels,
        datasets: [{
          label: label,
          data: values,
          backgroundColor: 'rgba(153, 102, 255, 0.6)',
          borderColor: 'rgba(153, 102, 255, 1)',
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        scales: {
          y: { beginAtZero: true }
        }
      }
    });
  }
};

const TemporalChart = {
  mounted() { this.renderChart(); },
  updated() { this.renderChart(); },
  renderChart() {
    const rawData = this.el.dataset.chart;
    const metric = this.el.dataset.metric || "accuracy";
    const period = this.el.dataset.period || "day";
    const data = JSON.parse(rawData);

    const labels = data.map(d => {
    const date = new Date(d.date);
    if (period === "month") return `${(date.getMonth() + 1).toString().padStart(2, "0")}/${date.getFullYear()}`;
    if (period === "week")  return `Sem. ${getISOWeek(date)}/${date.getFullYear()}`;
    return `${date.getDate().toString().padStart(2, "0")}/${(date.getMonth() + 1).toString().padStart(2, "0")}`;
  });


    let values;
    let yLabel, chartType, color;
    if (metric === "reaction_time") {
      values = data.map(d => d.value !== null ? parseFloat((d.value / 1000).toFixed(2)) : null);
      yLabel = "Tempo Médio (s)";
      color = "rgba(153, 102, 255, 0.6)";
    } else {
      values = data.map(d => d.value !== null ? (d.value * 100).toFixed(2) : null);
      yLabel = "Precisão Média (%)";
      color = "rgba(54, 162, 235, 0.6)";
    }

    chartType = "bar";

    if (this.chart) this.chart.destroy();
    const ctx = this.el.getContext("2d");
    this.chart = new Chart(ctx, {
      type: chartType,
      data: {
        labels: labels,
        datasets: [{
          label: yLabel,
          data: values,
          backgroundColor: color,
          borderColor: color.replace("0.6", "1"),
          borderWidth: 2,
          fill: chartType === "line"
        }]
      },
      options: {
        responsive: true,
        scales: {
          y: {
            beginAtZero: true,
            suggestedMax: metric === "accuracy" ? 100 : undefined,
            title: { display: true, text: yLabel }
          },
          x: {
            title: {
              display: true,
              text: period === "day" ? "Dias" : period === "week" ? "Semanas" : "Meses"
            }
          }
        }
      }
    });

    function getISOWeek(date) {
      const tmp = new Date(date.getTime());
      tmp.setHours(0, 0, 0, 0);
      tmp.setDate(tmp.getDate() + 3 - ((tmp.getDay() + 6) % 7));
      const week1 = new Date(tmp.getFullYear(), 0, 4);
      return 1 + Math.round(((tmp.getTime() - week1.getTime()) / 86400000 - 3 + ((week1.getDay() + 6) % 7)) / 7);
    }
  }
};

export { AccuracyChart, ReactionChart, PieChart, AccuracyStatChart, ReactionStatChart, TemporalChart };
