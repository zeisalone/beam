// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import { Drag, Drop } from "./hooks/drag_drop"
import Chart from 'chart.js/auto'
window.Chart = Chart

let Hooks = {
  Drag,
  Drop,
  AccuracyChart: {
    mounted() {
      console.log("AccuracyChart mounted");

      const rawData = this.el.dataset.chart;
      const data = JSON.parse(rawData);
      const labels = data.map(d => d.task_name);
      const values = data.map(d => (d.avg_accuracy * 100).toFixed(2));

      const ctx = this.el.getContext("2d");

      if (window.accuracyChartInstance) {
        window.accuracyChartInstance.destroy();
      }

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
            y: {
              beginAtZero: true,
              max: 100
            }
          }
        }
      });
    },
    updated() {
      console.log("AccuracyChart updated");
      const rawData = this.el.dataset.chart;
      const data = JSON.parse(rawData);
      const labels = data.map(d => d.task_name);
      const values = data.map(d => (d.avg_accuracy * 100).toFixed(2));

      const ctx = this.el.getContext("2d");

      if (window.accuracyChartInstance) {
        window.accuracyChartInstance.destroy();
      }

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
            y: {
              beginAtZero: true,
              max: 100
            }
          }
        }
      });
    }
  },
    ReactionChart: {
      mounted() {
        console.log("ReactionChart mounted");

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

        if (window.reactionChartInstance) {
          window.reactionChartInstance.destroy();
        }

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
              y: {
                beginAtZero: true
              }
            }
          }
        });
      },
      updated() {
        console.log("ReactionChart updated");

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

        if (window.reactionChartInstance) {
          window.reactionChartInstance.destroy();
        }

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
              y: {
                beginAtZero: true
              }
            }
          }
        });
      }
    },
    PieChart: {
    mounted() {
      this.renderChart();
    },
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
            plugins: {
              legend: {
                position: 'bottom'
              }
            }
          }
        });
      }, 100);
    }
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken}
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
