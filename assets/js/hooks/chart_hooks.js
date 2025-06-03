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
      data: data.map(d => d.avg_accuracy ? (d.avg_accuracy * 100).toFixed(2) : null),
      backgroundColor: 'rgba(54, 162, 235, 0.7)',
      borderColor: 'rgba(54, 162, 235, 1)',
      borderWidth: 1,
      barPercentage: 0.75,
      categoryPercentage: 0.75
    }];
    if (data.length && "general_avg_accuracy" in data[0]) {
      datasets.push({
        label: 'Média Geral',
        data: data.map(d => d.general_avg_accuracy ? (d.general_avg_accuracy * 100).toFixed(2) : null),
        backgroundColor: 'rgba(255, 193, 7, 0.7)',
        borderColor: 'rgba(255, 193, 7, 1)',
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
    const field = this.el.dataset.field || "avg_reaction_time";
    const label = this.el.dataset.label || "Tempo Médio (ms)";
    const data = JSON.parse(rawData);
    const patientName = this.el.dataset.patient || "Este Paciente";
    const labels = data.map(d => d.task_name);

    let datasets = [{
      label: patientName,
      data: data.map(d => d.avg_reaction_time !== undefined && d.avg_reaction_time !== null
        ? parseFloat(d.avg_reaction_time.toFixed(2))
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
          ? parseFloat(d.general_avg_reaction_time.toFixed(2))
          : null),
        backgroundColor: 'rgba(255, 193, 7, 0.7)',
        borderColor: 'rgba(255, 193, 7, 1)',
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

export { AccuracyChart, ReactionChart, PieChart, AccuracyStatChart, ReactionStatChart };
